-- =====================================================================
-- ProsperApp - Datos simulados - DML
-- Proyecto final - Bases de Datos
--
-- Este script pobla las 8 tablas con datos de prueba realistas.
-- IMPORTANTE: se debe ejecutar DESPUES de ddl.sql,
-- ya que ese script recrea las tablas vacias (y borra los datos si ya
-- existian).
--
-- Orden de insercion: respeta las dependencias de las FK. No se puede
-- insertar un proyecto sin que exista antes su usuario, ni una seccion
-- sin que exista antes su proyecto, etc.
-- =====================================================================

-- =====================================================================
-- 1. USUARIO (3 usuarios de prueba)
-- =====================================================================
INSERT INTO usuario (nombre, email, password_hash, rol) VALUES
('Jefferson Peña', 'jefferson.pena@correounivalle.edu.co', '$2b$12$fakedhash1abcdefghijklmno', 'admin'),
('Camila Rojas', 'camila.rojas@correounivalle.edu.co', '$2b$12$fakedhash2abcdefghijklmno', 'usuario'),
('Andrés Gómez', 'andres.gomez@correounivalle.edu.co', '$2b$12$fakedhash3abcdefghijklmno', 'usuario');

-- =====================================================================
-- 2. PROYECTO (cada usuario tiene 1 o 2 proyectos)
-- =====================================================================
INSERT INTO proyecto (nombre, descripcion, estado, id_usuario) VALUES
('ProsperApp', 'Herramienta para gestionar proyectos de software personales.', 'activo', 1),
('Bot de Telegram para recordatorios', 'Prueba de concepto de un bot que envía recordatorios diarios.', 'activo', 1),
('Rediseño de portafolio personal', 'Sitio web con Next.js para mostrar proyectos propios.', 'archivado', 2),
('API de finanzas personales', 'Backend en FastAPI para llevar control de gastos.', 'activo', 3);

-- =====================================================================
-- 3. SECCION (entre 3 y 4 secciones por proyecto, dentro del limite de 6)
-- =====================================================================
-- Proyecto 1: ProsperApp
INSERT INTO seccion (nombre, orden, id_proyecto) VALUES
('Backlog', 1, 1),
('Doing', 2, 1),
('Completed', 3, 1),
('Release', 4, 1);

-- Proyecto 2: Bot de Telegram
INSERT INTO seccion (nombre, orden, id_proyecto) VALUES
('Backlog', 1, 2),
('Doing', 2, 2),
('Completed', 3, 2);

-- Proyecto 3: Portafolio personal
INSERT INTO seccion (nombre, orden, id_proyecto) VALUES
('Backlog', 1, 3),
('Doing', 2, 3),
('Completed', 3, 3);

-- Proyecto 4: API de finanzas
INSERT INTO seccion (nombre, orden, id_proyecto) VALUES
('Backlog', 1, 4),
('Doing', 2, 4),
('Completed', 3, 4),
('Release', 4, 4);

-- =====================================================================
-- 4. FUNCIONALIDAD (varias tarjetas repartidas en las secciones de arriba)
-- =====================================================================
-- Funcionalidades del proyecto 1 (secciones 1-4: Backlog, Doing, Completed, Release)
INSERT INTO funcionalidad (titulo, historia_usuario, descripcion_detallada, prioridad, orden, id_seccion) VALUES
('Autenticación de usuarios', 'Como usuario quiero registrarme e iniciar sesión para acceder a mis proyectos.', 'Login con email y contraseña, hash con bcrypt.', 'alta', 1, 1),
('Tablero Kanban', 'Como usuario quiero ver mis funcionalidades organizadas en columnas para seguir el progreso.', 'Drag and drop entre secciones.', 'alta', 2, 1),
('Checklist de subtareas', 'Como usuario quiero dividir una funcionalidad en subtareas para organizarme mejor.', NULL, 'media', 1, 2),
('Notas de diseño por funcionalidad', 'Como usuario quiero anotar decisiones de diseño dentro de cada tarjeta.', NULL, 'media', 1, 3),
('Exportar proyecto a PDF', 'Como usuario quiero exportar el resumen de mi proyecto en PDF.', 'Se usa la librería reportlab en el backend.', 'baja', 1, 4);

-- Funcionalidades del proyecto 2 (secciones 5-7)
INSERT INTO funcionalidad (titulo, historia_usuario, prioridad, orden, id_seccion) VALUES
('Comando /recordar', 'Como usuario quiero escribir /recordar para programar un aviso.', 'alta', 1, 5),
('Notificaciones diarias', 'Como usuario quiero recibir un resumen diario de mis pendientes.', 'media', 1, 6);

-- Funcionalidades del proyecto 3 (secciones 8-10)
INSERT INTO funcionalidad (titulo, historia_usuario, prioridad, orden, id_seccion) VALUES
('Sección de proyectos destacados', 'Como visitante quiero ver los proyectos más relevantes primero.', 'media', 1, 8),
('Modo oscuro', 'Como visitante quiero cambiar entre modo claro y oscuro.', 'baja', 1, 9);

-- Funcionalidades del proyecto 4 (secciones 11-14)
INSERT INTO funcionalidad (titulo, historia_usuario, prioridad, orden, id_seccion) VALUES
('Registro de gastos por categoría', 'Como usuario quiero clasificar mis gastos para ver en qué gasto más.', 'alta', 1, 11),
('Reporte mensual', 'Como usuario quiero un resumen mensual de ingresos y gastos.', 'media', 1, 12);

-- =====================================================================
-- 5. SUBTAREA (checklist de algunas funcionalidades)
-- =====================================================================
INSERT INTO subtarea (descripcion, completada, orden, id_funcionalidad) VALUES
('Diseñar tabla usuario', TRUE, 1, 1),
('Implementar hash de contraseña', TRUE, 2, 1),
('Crear endpoint de login', FALSE, 3, 1),
('Crear endpoint de registro', FALSE, 4, 1),
('Definir modelo de datos de subtarea', TRUE, 1, 3),
('Conectar checklist con la UI', FALSE, 2, 3);

-- =====================================================================
-- 6. NOTA_DISENO
-- =====================================================================
INSERT INTO nota_diseno (contenido, id_funcionalidad) VALUES
('Se decidió usar JWT en vez de sesiones para facilitar el escalado horizontal.', 1),
('El drag and drop se implementará con la librería dnd-kit por su buen soporte de accesibilidad.', 2),
('Evaluar si el checklist necesita fechas límite en una futura iteración.', 3);

-- =====================================================================
-- 7. FRAGMENTO_CODIGO
-- =====================================================================
INSERT INTO fragmento_codigo (lenguaje, codigo, descripcion, id_funcionalidad) VALUES
('SQL', 'SELECT * FROM usuario WHERE email = $1;', 'Consulta base para el login', 1),
('JavaScript', 'function moverTarjeta(id, nuevaSeccion) { /* actualiza id_seccion */ }', 'Función de drag and drop', 2);

-- =====================================================================
-- 8. DECISION_TECNICA
-- =====================================================================
INSERT INTO decision_tecnica (descripcion, justificacion, id_funcionalidad) VALUES
('Usar PostgreSQL como motor de base de datos.', 'Soporta triggers, CHECK constraints avanzados y es gratuito, ideal para el alcance del curso.', 1),
('Separar notas, código y decisiones en tablas propias en vez de columnas de texto.', 'Permite guardar varios registros de cada tipo por funcionalidad y cumple con la Primera Forma Normal (1FN).', 2);
