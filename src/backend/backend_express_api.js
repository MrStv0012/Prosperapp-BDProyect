const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'prosper_secret_key_123_456';

app.use(cors());
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

pool.connect((err, client, release) => {
  if (err) {
    console.error('❌ Error de conexión a PostgreSQL:', err.stack);
  } else {
    console.log('✅ Conexión exitosa a la base de datos de ProsperApp');
    release();
  }
});

/**
 * Traduce y limpia los mensajes de error técnicos de la base de datos,
 * eliminando nombres de funciones, triggers y detalles entre paréntesis.
 */
const handleDatabaseError = (err, res) => {
  let errorMessage = err.message || 'Ocurrió un error inesperado en la base de datos.';
  
  // Captura de violaciones de triggers (Código de error P0001 de PL/pgSQL)
  if (err.code === 'P0001') {
    if (errorMessage.includes('trg_max_secciones') || errorMessage.includes('max_secciones')) {
      return res.status(400).json({ error: 'Violación de Regla de Negocio: Un proyecto no puede tener más de 6 secciones.' });
    }
    if (errorMessage.includes('trg_min_secciones') || errorMessage.includes('min_secciones')) {
      return res.status(400).json({ error: 'Violación de Regla de Negocio: Un proyecto no puede quedar sin secciones.' });
    }
    if (errorMessage.includes('trg_no_autoinvitar') || errorMessage.includes('validar_no_autoinvitar') || errorMessage.includes('dueño del proyecto')) {
      return res.status(400).json({ error: 'Violación de Regla de Negocio: El dueño del proyecto no puede agregarse como colaborador.' });
    }
  }

  // Captura de unicidad (Llave duplicada)
  if (err.code === '23505') {
    if (errorMessage.includes('uq_seccion_orden')) {
      return res.status(400).json({ error: 'Ya existe una sección con esta posición de orden.' });
    }
    if (errorMessage.includes('colaborador_proyecto_pkey')) {
      return res.status(400).json({ error: 'Este usuario ya está asignado como colaborador del proyecto.' });
    }
    if (errorMessage.includes('usuario_email_key')) {
      return res.status(400).json({ error: 'El correo electrónico ya se encuentra registrado.' });
    }
  }

  // Captura de CHECK Constraints
  if (err.code === '23514') {
    if (errorMessage.includes('orden')) {
      return res.status(400).json({ error: 'El orden de las tarjetas o secciones no puede ser un número negativo.' });
    }
  }

  // Remover cualquier texto residual entre paréntesis para mayor limpieza visual
  const cleanMessage = errorMessage
    .replace(/\(.*?\)/g, '') // Elimina todo lo que esté entre paréntesis
    .replace('EXCEPTION:', '')
    .replace('error:', '')
    .trim();

  return res.status(500).json({ error: cleanMessage });
};

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Acceso denegado. Token no suministrado.' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido o expirado.' });
    }
    req.user = user;
    next();
  });
};

const verificarAccesoProyecto = (obtenerIdProyecto) => {
  return async (req, res, next) => {
    try {
      const idProyecto = await obtenerIdProyecto(req);
      if (!idProyecto) {
        return res.status(404).json({ error: 'Recurso no encontrado.' });
      }
 
      const query = `
        SELECT 1 FROM proyecto WHERE id_proyecto = $1 AND id_usuario = $2
        UNION
        SELECT 1 FROM colaborador_proyecto WHERE id_proyecto = $1 AND id_usuario = $2;
      `;
      const result = await pool.query(query, [idProyecto, req.user.id_usuario]);
 
      if (result.rows.length === 0) {
        return res.status(403).json({ error: 'No tienes acceso a este proyecto.' });
      }
      next();
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  };
};

app.post('/api/auth/register', async (req, res) => {
  const { nombre, email, password, rol } = req.body;

  if (!nombre || !email || !password) {
    return res.status(400).json({ error: 'Todos los campos son obligatorios.' });
  }

  try {
    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(password, salt);
    const userRol = 'usuario'; 

    const query = `
      INSERT INTO usuario (nombre, email, password_hash, rol, fecha_registro)
      VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
      RETURNING id_usuario, nombre, email, rol, fecha_registro;
    `;
    const result = await pool.query(query, [nombre, email, passwordHash, userRol]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    return handleDatabaseError(err, res);
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Suministre email y contraseña.' });
  }

  try {
    const query = 'SELECT * FROM usuario WHERE email = $1';
    const result = await pool.query(query, [email]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales inválidas.' });
    }

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Credenciales inválidas.' });
    }

    const token = jwt.sign(
      { id_usuario: user.id_usuario, nombre: user.nombre, email: user.email, rol: user.rol },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      token,
      user: {
        id_usuario: user.id_usuario,
        nombre: user.nombre,
        email: user.email,
        rol: user.rol
      }
    });
  } catch (err) {
    return handleDatabaseError(err, res);
  }
});

app.get('/api/proyectos', authenticateToken, async (req, res) => {
  const userId = req.user.id_usuario;

  try {
    const query = `
      WITH proyectos_accesibles AS (
          SELECT p.id_proyecto, p.nombre, p.descripcion, p.fecha_creacion, p.estado, 'dueño' AS rol_acceso
          FROM proyecto p
          WHERE p.id_usuario = $1
          
          UNION
          
          SELECT p.id_proyecto, p.nombre, p.descripcion, p.fecha_creacion, p.estado, cp.rol_colaborador AS rol_acceso
          FROM proyecto p
          JOIN colaborador_proyecto cp ON cp.id_proyecto = p.id_proyecto
          WHERE cp.id_usuario = $1
      )
      SELECT pa.*,
             COALESCE(
                 (
                     SELECT ROUND(
                         100.0 * COUNT(f.id_funcionalidad) FILTER (
                             WHERE s.orden = (SELECT MAX(s2.orden) FROM seccion s2 WHERE s2.id_proyecto = pa.id_proyecto)
                         ) / NULLIF(COUNT(f.id_funcionalidad), 0),
                         1
                     )
                     FROM seccion s
                     LEFT JOIN funcionalidad f ON f.id_seccion = s.id_seccion
                     WHERE s.id_proyecto = pa.id_proyecto
                 ), 
                 0.0
             )::float AS porcentaje_avance
      FROM proyectos_accesibles pa
      ORDER BY pa.nombre;
    `;
    const result = await pool.query(query, [userId]);
    res.json(result.rows);
  } catch (err) {
    return handleDatabaseError(err, res);
  }
});

app.post('/api/proyectos', authenticateToken, async (req, res) => {
  const { nombre, descripcion, secciones } = req.body; 
  const userId = req.user.id_usuario;

  if (!nombre) {
    return res.status(400).json({ error: 'El nombre del proyecto es obligatorio.' });
  }
  if (!secciones || secciones.length < 1 || secciones.length > 6) {
    return res.status(400).json({ error: 'Un proyecto debe tener entre 1 y 6 secciones.' });
  }

  try {
    await pool.query('BEGIN');

    const insertProyecto = `
      INSERT INTO proyecto (nombre, descripcion, id_usuario, estado)
      VALUES ($1, $2, $3, 'activo')
      RETURNING *;
    `;
    const projRes = await pool.query(insertProyecto, [nombre, descripcion, userId]);
    const nuevoProyecto = projRes.rows[0];

    for (let i = 0; i < secciones.length; i++) {
      const seccionNombre = secciones[i];
      const orden = i + 1; 
      const insertSeccion = `
        INSERT INTO seccion (nombre, orden, id_proyecto)
        VALUES ($1, $2, $3);
      `;
      await pool.query(insertSeccion, [seccionNombre, orden, nuevoProyecto.id_proyecto]);
    }

    await pool.query('COMMIT');
    res.status(201).json(nuevoProyecto);
  } catch (err) {
    await pool.query('ROLLBACK');
    return handleDatabaseError(err, res);
  }
});

app.get('/api/pendientes', authenticateToken, async (req, res) => {
  const userId = req.user.id_usuario;

  try {
    const query = `
      WITH proyectos_usuario AS (
          SELECT p.id_proyecto, p.nombre AS proyecto, u.nombre AS usuario, p.id_usuario
          FROM proyecto p
          JOIN usuario u ON u.id_usuario = p.id_usuario
          
          UNION
          
          SELECT p.id_proyecto, p.nombre AS proyecto, u.nombre AS usuario, cp.id_usuario
          FROM proyecto p
          JOIN colaborador_proyecto cp ON cp.id_proyecto = p.id_proyecto
          JOIN usuario u ON u.id_usuario = cp.id_usuario
      )
      SELECT
          pu.proyecto,
          s.nombre  AS seccion_actual,
          f.id_funcionalidad,
          f.titulo,
          f.prioridad
      FROM proyectos_usuario pu
      JOIN seccion s        ON s.id_proyecto = pu.id_proyecto
      JOIN funcionalidad f  ON f.id_seccion = s.id_seccion
      WHERE pu.id_usuario = $1
        AND f.prioridad = 'alta'
        AND s.orden < (SELECT MAX(s2.orden) FROM seccion s2 WHERE s2.id_proyecto = pu.id_proyecto)
      ORDER BY pu.proyecto, f.titulo;
    `;
    const result = await pool.query(query, [userId]);
    res.json(result.rows);
  } catch (err) {
    return handleDatabaseError(err, res);
  }
});

app.get('/api/proyectos/:id/tablero', authenticateToken, async (req, res) => {
  const idProyecto = req.params.id;
  const userId = req.user.id_usuario;

  try {
    const validacionQuery = `
      SELECT p.id_proyecto, p.id_usuario, cp.rol_colaborador
      FROM proyecto p
      LEFT JOIN colaborador_proyecto cp ON p.id_proyecto = cp.id_proyecto AND cp.id_usuario = $1
      WHERE p.id_proyecto = $2 AND (p.id_usuario = $1 OR cp.id_usuario = $1);
    `;
    const validacion = await pool.query(validacionQuery, [userId, idProyecto]);
    if (validacion.rows.length === 0) {
      return res.status(403).json({ error: 'No cuentas con autorización para este proyecto.' });
    }

    const rolAcceso = validacion.rows[0].id_usuario === userId ? 'dueño' : validacion.rows[0].rol_colaborador;

    const querySecciones = 'SELECT * FROM seccion WHERE id_proyecto = $1 ORDER BY orden ASC;';
    const seccionesRes = await pool.query(querySecciones, [idProyecto]);

    const queryFuncionalidades = `
      SELECT f.*, 
        (SELECT COUNT(*) FROM subtarea sub WHERE sub.id_funcionalidad = f.id_funcionalidad) AS total_subtareas,
        (SELECT COUNT(*) FROM subtarea sub WHERE sub.id_funcionalidad = f.id_funcionalidad AND sub.completada = true) AS completadas_subtareas
      FROM funcionalidad f
      JOIN seccion s ON f.id_seccion = s.id_seccion
      WHERE s.id_proyecto = $1
      ORDER BY f.orden ASC;
    `;
    const funcionalidadesRes = await pool.query(queryFuncionalidades, [idProyecto]);

    const tablero = seccionesRes.rows.map(sec => {
      return {
        ...sec,
        funcionalidades: funcionalidadesRes.rows.filter(func => func.id_seccion === sec.id_seccion)
      };
    });

    res.json({ rol_acceso: rolAcceso, tablero });
  } catch (err) {
    return handleDatabaseError(err, res);
  }
});

app.post('/api/secciones', authenticateToken, async (req, res) => {
  const { nombre, orden, id_proyecto } = req.body;

  try {
    const query = `
      INSERT INTO seccion (nombre, orden, id_proyecto) 
      VALUES ($1, $2, $3) 
      RETURNING *;
    `;
    const result = await pool.query(query, [nombre, orden, id_proyecto]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    return handleDatabaseError(err, res);
  }
});

app.delete('/api/secciones/:id', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query('SELECT id_proyecto FROM seccion WHERE id_seccion = $1', [req.params.id]);
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idSeccion = req.params.id;
    try {
      await pool.query('DELETE FROM seccion WHERE id_seccion = $1', [idSeccion]);
      res.json({ mensaje: 'Sección eliminada con éxito.' });
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.post('/api/funcionalidades', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query('SELECT id_proyecto FROM seccion WHERE id_seccion = $1', [req.body.id_seccion]);
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const { titulo, historia_usuario, descripcion_detallada, prioridad, orden, id_seccion } = req.body;
    try {
      const query = `
        INSERT INTO funcionalidad (titulo, historia_usuario, descripcion_detallada, prioridad, orden, id_seccion)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *;
      `;
      const result = await pool.query(query, [titulo, historia_usuario, descripcion_detallada, prioridad || 'media', orden || 0, id_seccion]);
      res.status(201).json(result.rows[0]);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);


app.get('/api/funcionalidades/:id', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM funcionalidad f
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE f.id_funcionalidad = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idFuncionalidad = req.params.id;
    try {
      const cardQuery = `
        SELECT
            f.id_funcionalidad, f.titulo, f.historia_usuario, f.descripcion_detallada,
            f.prioridad, f.id_seccion,
            COALESCE((SELECT json_agg(json_build_object('id_nota', n.id_nota, 'contenido', n.contenido, 'fecha', n.fecha))
                      FROM nota_diseno n WHERE n.id_funcionalidad = f.id_funcionalidad), '[]'::json) AS notas_diseno,
            COALESCE((SELECT json_agg(json_build_object('id_fragmento', c.id_fragmento, 'lenguaje', c.lenguaje, 'codigo', c.codigo, 'descripcion', c.descripcion))
                      FROM fragmento_codigo c WHERE c.id_funcionalidad = f.id_funcionalidad), '[]'::json) AS fragmentos_codigo,
            COALESCE((SELECT json_agg(json_build_object('id_decision', d.id_decision, 'descripcion', d.descripcion, 'justificacion', d.justificacion, 'fecha', d.fecha))
                      FROM decision_tecnica d WHERE d.id_funcionalidad = f.id_funcionalidad), '[]'::json) AS decisiones_tecnicas
        FROM funcionalidad f
        WHERE f.id_funcionalidad = $1;
      `;
      const cardRes = await pool.query(cardQuery, [idFuncionalidad]);
      if (cardRes.rows.length === 0) {
        return res.status(404).json({ error: 'La funcionalidad especificada no existe.' });
      }
      const card = cardRes.rows[0];
 
      const subRes = await pool.query(
        'SELECT id_subtarea, descripcion, completada, orden FROM subtarea WHERE id_funcionalidad = $1 ORDER BY orden;',
        [idFuncionalidad]
      );
      card.subtareas = subRes.rows;
      res.json(card);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.put('/api/funcionalidades/:id/mover', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM funcionalidad f
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE f.id_funcionalidad = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idFuncionalidad = req.params.id;
    const { id_seccion, orden } = req.body;
    try {
      const query = `
        UPDATE funcionalidad
        SET id_seccion = $1, orden = COALESCE($2, orden)
        WHERE id_funcionalidad = $3
        RETURNING *;
      `;
      const result = await pool.query(query, [id_seccion, orden || 0, idFuncionalidad]);
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Funcionalidad no encontrada.' });
      }
      res.json({ mensaje: 'Funcionalidad movida con éxito', funcionalidad: result.rows[0] });
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.post('/api/funcionalidades/:id/subtareas', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM funcionalidad f
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE f.id_funcionalidad = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idFuncionalidad = req.params.id;
    const { descripcion, orden } = req.body;
    try {
      const query = `
        INSERT INTO subtarea (descripcion, completada, orden, id_funcionalidad)
        VALUES ($1, false, $2, $3)
        RETURNING *;
      `;
      const result = await pool.query(query, [descripcion, orden || 0, idFuncionalidad]);
      res.status(201).json(result.rows[0]);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.put('/api/subtareas/:id/toggle', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM subtarea sub
       JOIN funcionalidad f ON f.id_funcionalidad = sub.id_funcionalidad
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE sub.id_subtarea = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idSubtarea = req.params.id;
    const { completada } = req.body;
    try {
      const query = 'UPDATE subtarea SET completada = $1 WHERE id_subtarea = $2 RETURNING *;';
      const result = await pool.query(query, [completada, idSubtarea]);
      res.json(result.rows[0]);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.post('/api/funcionalidades/:id/notas', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM funcionalidad f
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE f.id_funcionalidad = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idFuncionalidad = req.params.id;
    const { contenido } = req.body;
    try {
      const query = `INSERT INTO nota_diseno (contenido, id_funcionalidad) VALUES ($1, $2) RETURNING *;`;
      const result = await pool.query(query, [contenido, idFuncionalidad]);
      res.status(201).json(result.rows[0]);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.post('/api/funcionalidades/:id/fragmentos', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM funcionalidad f
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE f.id_funcionalidad = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idFuncionalidad = req.params.id;
    const { lenguaje, codigo, descripcion } = req.body;
    try {
      const query = `INSERT INTO fragmento_codigo (lenguaje, codigo, descripcion, id_funcionalidad) VALUES ($1, $2, $3, $4) RETURNING *;`;
      const result = await pool.query(query, [lenguaje, codigo, descripcion, idFuncionalidad]);
      res.status(201).json(result.rows[0]);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.post('/api/funcionalidades/:id/decisiones', authenticateToken,
  verificarAccesoProyecto(async (req) => {
    const r = await pool.query(
      `SELECT s.id_proyecto FROM funcionalidad f
       JOIN seccion s ON s.id_seccion = f.id_seccion
       WHERE f.id_funcionalidad = $1`,
      [req.params.id]
    );
    return r.rows[0]?.id_proyecto;
  }),
  async (req, res) => {
    const idFuncionalidad = req.params.id;
    const { descripcion, justificacion } = req.body;
    try {
      const query = `INSERT INTO decision_tecnica (descripcion, justificacion, id_funcionalidad) VALUES ($1, $2, $3) RETURNING *;`;
      const result = await pool.query(query, [descripcion, justificacion, idFuncionalidad]);
      res.status(201).json(result.rows[0]);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.get('/api/proyectos/:id/colaboradores', authenticateToken,
  verificarAccesoProyecto(async (req) => req.params.id), // aqui la URL YA trae el id_proyecto directo
  async (req, res) => {
    const idProyecto = req.params.id;
    try {
      const query = `
        SELECT u.id_usuario, u.nombre, u.email, cp.rol_colaborador, cp.fecha_union
        FROM colaborador_proyecto cp
        JOIN usuario u ON u.id_usuario = cp.id_usuario
        WHERE cp.id_proyecto = $1
        ORDER BY cp.fecha_union;
      `;
      const result = await pool.query(query, [idProyecto]);
      res.json(result.rows);
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.post('/api/proyectos/:id/colaboradores', authenticateToken,
  verificarAccesoProyecto(async (req) => req.params.id),
  async (req, res) => {
    const idProyecto = req.params.id;
    const { email, rol_colaborador } = req.body;
    if (!email || !rol_colaborador) {
      return res.status(400).json({ error: 'Suministre email y el rol del colaborador.' });
    }
    try {
      const userRes = await pool.query('SELECT id_usuario FROM usuario WHERE email = $1', [email]);
      if (userRes.rows.length === 0) {
        return res.status(404).json({ error: 'No se encontró un usuario con ese correo electrónico.' });
      }
      const invitedUserId = userRes.rows[0].id_usuario;
      const insertQuery = `
        INSERT INTO colaborador_proyecto (id_proyecto, id_usuario, rol_colaborador, fecha_union)
        VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
        RETURNING *;
      `;
      await pool.query(insertQuery, [idProyecto, invitedUserId, rol_colaborador]);
      res.status(201).json({ mensaje: 'Colaborador invitado exitosamente.' });
    } catch (err) {
      return handleDatabaseError(err, res);
    }
  }
);

app.listen(PORT, () => {
  console.log(`🚀 Servidor de ProsperApp corriendo exitosamente en el puerto ${PORT}`);
});
