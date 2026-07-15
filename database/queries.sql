-- =====================================================================
-- ProsperApp - Consultas de la aplicacion
-- Proyecto final - Bases de Datos
--
-- Este script agrupa las consultas SQL que la aplicacion necesitaria
-- ejecutar en su uso diario: cargar el tablero de un proyecto, calcular
-- el progreso, traer la "ficha" completa de una funcionalidad, listar
-- los proyectos accesibles por un usuario (como dueño o colaborador),
-- gestionar colaboradores, etc.
--
-- IMPORTANTE: se debe ejecutar DESPUES de ddl.sql y dml.sql
-- ya que estas consultas leen datos de las tablas ya pobladas.
--
-- Cada bloque de consulta esta comentado explicando en que pantalla o
-- accion de la app se usaria.
-- =====================================================================


-- =====================================================================
-- CONSULTA 1: Tablero completo de un proyecto
-- Uso en la app: pantalla principal del tablero (vista Kanban).
-- Trae todas las secciones de un proyecto junto con sus funcionalidades,
-- ordenadas por la posicion de la seccion y el orden de la tarjeta
-- dentro de la columna.
-- =====================================================================
SELECT
    s.id_seccion,
    s.nombre        AS seccion,
    s.orden         AS orden_seccion,
    f.id_funcionalidad,
    f.titulo,
    f.prioridad,
    f.orden         AS orden_tarjeta
FROM seccion s
LEFT JOIN funcionalidad f ON f.id_seccion = s.id_seccion
WHERE s.id_proyecto = 1   -- id del proyecto que se este viendo en la app
ORDER BY s.orden, f.orden;


-- =====================================================================
-- CONSULTA 2: Progreso general de cada proyecto
-- Uso en la app: dashboard principal (indicadores de progreso).
-- Calcula el porcentaje de funcionalidades que estan en la ultima
-- seccion del tablero de cada proyecto (se asume que la seccion con
-- mayor "orden" representa el estado "terminado", ej. Completed/Release).
-- =====================================================================
SELECT
    p.id_proyecto,
    p.nombre AS proyecto,
    COUNT(f.id_funcionalidad) AS total_funcionalidades,
    COUNT(f.id_funcionalidad) FILTER (
        WHERE s.orden = (SELECT MAX(s2.orden) FROM seccion s2 WHERE s2.id_proyecto = p.id_proyecto)
    ) AS funcionalidades_en_ultima_seccion,
    ROUND(
        100.0 * COUNT(f.id_funcionalidad) FILTER (
            WHERE s.orden = (SELECT MAX(s2.orden) FROM seccion s2 WHERE s2.id_proyecto = p.id_proyecto)
        ) / NULLIF(COUNT(f.id_funcionalidad), 0),
        1
    ) AS porcentaje_avance
FROM proyecto p
LEFT JOIN seccion s ON s.id_proyecto = p.id_proyecto
LEFT JOIN funcionalidad f ON f.id_seccion = s.id_seccion
GROUP BY p.id_proyecto, p.nombre
ORDER BY p.id_proyecto;


-- =====================================================================
-- CONSULTA 3: Checklist de subtareas de una funcionalidad, con avance
-- Uso en la app: dentro de la tarjeta, seccion "Subtareas".
-- Muestra cada subtarea y ademas el porcentaje de subtareas completadas
-- para esa funcionalidad especifica.
-- =====================================================================
SELECT
    f.id_funcionalidad,
    f.titulo,
    sub.id_subtarea,
    sub.descripcion,
    sub.completada,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sub.completada) OVER (PARTITION BY f.id_funcionalidad)
        / COUNT(*) OVER (PARTITION BY f.id_funcionalidad),
        1
    ) AS porcentaje_avance_checklist
FROM funcionalidad f
JOIN subtarea sub ON sub.id_funcionalidad = f.id_funcionalidad
WHERE f.id_funcionalidad = 1   -- id de la funcionalidad que se este viendo
ORDER BY sub.orden;


-- =====================================================================
-- CONSULTA 4: Ficha completa de una funcionalidad
-- Uso en la app: al abrir el detalle de una tarjeta, se necesita traer
-- de una vez la historia de usuario, sus notas de diseno, fragmentos
-- de codigo y decisiones tecnicas asociadas.
--
-- Nota de diseno: como una funcionalidad puede tener VARIAS notas,
-- VARIOS fragmentos y VARIAS decisiones, un solo JOIN directo entre
-- las 4 tablas satelite generaria un producto cartesiano (filas
-- repetidas y mezcladas). Por eso aqui se usan sub-consultas con
-- json_agg: cada una arma su propio arreglo de resultados por separado,
-- y al final se combinan en una sola fila por funcionalidad.
-- =====================================================================
SELECT
    f.id_funcionalidad,
    f.titulo,
    f.historia_usuario,
    f.descripcion_detallada,
    f.prioridad,
    (SELECT json_agg(json_build_object('contenido', n.contenido, 'fecha', n.fecha))
     FROM nota_diseno n WHERE n.id_funcionalidad = f.id_funcionalidad)      AS notas_diseno,
    (SELECT json_agg(json_build_object('lenguaje', c.lenguaje, 'codigo', c.codigo))
     FROM fragmento_codigo c WHERE c.id_funcionalidad = f.id_funcionalidad) AS fragmentos_codigo,
    (SELECT json_agg(json_build_object('descripcion', d.descripcion, 'justificacion', d.justificacion))
     FROM decision_tecnica d WHERE d.id_funcionalidad = f.id_funcionalidad) AS decisiones_tecnicas
FROM funcionalidad f
WHERE f.id_funcionalidad = 1;


-- =====================================================================
-- CONSULTA 5 : Proyectos accesibles por un usuario
-- Uso en la app: pantalla "Mis proyectos" / dashboard principal.
-- Un usuario puede ver un proyecto por dos caminos distintos: siendo
-- el dueño (proyecto.id_usuario) o siendo colaborador
-- (colaborador_proyecto). Se combinan ambos casos con UNION y se
-- etiqueta el tipo de acceso en la columna rol_acceso, para que la UI
-- pueda mostrar un tag ("Dueño", "Editor", "Lector") junto al proyecto.
-- =====================================================================
SELECT
    p.id_proyecto,
    p.nombre,
    p.estado,
    'dueño' AS rol_acceso
FROM proyecto p
WHERE p.id_usuario = 1   -- id del usuario que inicio sesion

UNION

SELECT
    p.id_proyecto,
    p.nombre,
    p.estado,
    cp.rol_colaborador AS rol_acceso
FROM proyecto p
JOIN colaborador_proyecto cp ON cp.id_proyecto = p.id_proyecto
WHERE cp.id_usuario = 1   -- mismo id del usuario que inicio sesion

ORDER BY nombre;


-- =====================================================================
-- CONSULTA 6: Funcionalidades de alta prioridad
-- pendientes por usuario
-- Uso en la app: seccion "Mis pendientes urgentes" del dashboard.
-- Antes esta consulta solo recorria proyecto.id_usuario (el dueño).
-- Ahora, con colaboradores, un usuario tambien tiene pendientes en
-- proyectos ajenos donde colabora. El CTE proyectos_usuario junta
-- ambos casos (dueño + colaborador) igual que la Consulta 5, y el
-- resto de la consulta queda igual que antes: busca tarjetas de
-- prioridad alta que no estan todavia en la ultima seccion.
-- =====================================================================
WITH proyectos_usuario AS (
    SELECT p.id_proyecto, p.nombre AS proyecto, u.nombre AS usuario
    FROM proyecto p
    JOIN usuario u ON u.id_usuario = p.id_usuario

    UNION

    SELECT p.id_proyecto, p.nombre AS proyecto, u.nombre AS usuario
    FROM proyecto p
    JOIN colaborador_proyecto cp ON cp.id_proyecto = p.id_proyecto
    JOIN usuario u ON u.id_usuario = cp.id_usuario
)
SELECT
    pu.usuario,
    pu.proyecto,
    s.nombre  AS seccion_actual,
    f.titulo,
    f.prioridad
FROM proyectos_usuario pu
JOIN seccion s        ON s.id_proyecto = pu.id_proyecto
JOIN funcionalidad f  ON f.id_seccion = s.id_seccion
WHERE f.prioridad = 'alta'
  AND s.orden < (SELECT MAX(s2.orden) FROM seccion s2 WHERE s2.id_proyecto = pu.id_proyecto)
ORDER BY pu.usuario, pu.proyecto;


-- =====================================================================
-- CONSULTA 7: Colaboradores de un proyecto
-- Uso en la app: pantalla de "Gestionar acceso" dentro de un proyecto,
-- donde el dueño ve quien mas tiene acceso y con que rol.
-- =====================================================================
SELECT
    u.id_usuario,
    u.nombre,
    u.email,
    cp.rol_colaborador,
    cp.fecha_union
FROM colaborador_proyecto cp
JOIN usuario u ON u.id_usuario = cp.id_usuario
WHERE cp.id_proyecto = 1   -- id del proyecto que se este gestionando
ORDER BY cp.fecha_union;


-- =====================================================================
-- CONSULTA 8: Mover una funcionalidad de seccion (drag and drop)
-- Uso en la app: cuando el usuario arrastra una tarjeta de una columna
-- a otra. Como se explico en el DDL, esto es un UPDATE del campo
-- id_seccion, no la creacion de una fila nueva.
-- =====================================================================
UPDATE funcionalidad
SET id_seccion = 2   -- id de la seccion destino (ej. "Doing")
WHERE id_funcionalidad = 4;


-- =====================================================================
-- CONSULTA 9 (TRANSACCION): crear un proyecto junto con su seccion
-- "Backlog" por defecto
-- Uso en la app: al dar click en "Nuevo proyecto".
--
-- Como se explica en los comentarios del DDL, la base de datos no
-- puede exigir por si sola que un proyecto tenga minimo 1 seccion en
-- el momento de crearse (todavia no existe ninguna seccion). Por eso
-- es responsabilidad de la aplicacion crear el proyecto Y su primera
-- seccion en una sola transaccion: si algo falla a la mitad, con
-- ROLLBACK no queda un proyecto sin ninguna seccion.
-- =====================================================================
BEGIN;

INSERT INTO proyecto (nombre, descripcion, id_usuario)
VALUES ('Nuevo proyecto de prueba', 'Descripcion del nuevo proyecto', 2)
RETURNING id_proyecto;
-- (en la aplicacion, el id_proyecto que retorna este INSERT se usaria
-- directamente en el siguiente INSERT; aqui se deja el numero fijo
-- solo para poder probar el script manualmente)

INSERT INTO seccion (nombre, orden, id_proyecto)
VALUES ('Backlog', 1, (SELECT MAX(id_proyecto) FROM proyecto));

COMMIT;
-- Si algo hubiera fallado entre el BEGIN y el COMMIT (por ejemplo, un
-- error de conexion o una validacion que falla en la aplicacion), se
-- ejecutaria ROLLBACK; en vez de COMMIT; y ninguno de los dos INSERT
-- quedaria guardado, evitando el proyecto huerfano sin secciones.


-- =====================================================================
-- CONSULTA 10: Invitar un colaborador a un proyecto
-- Uso en la app: al dar click en "Invitar colaborador" dentro de un
-- proyecto. Es un INSERT directo; el trigger trg_no_autoinvitar se
-- encarga de rechazarlo si el usuario invitado resulta ser el dueño.
-- =====================================================================
INSERT INTO colaborador_proyecto (id_proyecto, id_usuario, rol_colaborador)
VALUES (2, 3, 'lector');   -- invita a Andrés (3) como lector del proyecto 2


-- =====================================================================
-- CONSULTA 11: Intento de insertar una septima seccion (prueba del trigger)
-- Uso: no es una consulta de la aplicacion, sino una prueba para
-- demostrar que el trigger trg_max_secciones si esta funcionando.
-- Se puede correr sola (descomentada) sobre el proyecto 1, que ya
-- tiene 4 secciones; para probar el limite habria que insertar hasta
-- llegar a 6 y luego intentar una septima, que deberia lanzar error.
-- =====================================================================
-- INSERT INTO seccion (nombre, orden, id_proyecto) VALUES ('Extra 1', 5, 1);
-- INSERT INTO seccion (nombre, orden, id_proyecto) VALUES ('Extra 2', 6, 1);
-- INSERT INTO seccion (nombre, orden, id_proyecto) VALUES ('Extra 3', 7, 1);
-- Esta ultima deberia fallar con:
-- ERROR: Un proyecto no puede tener mas de 6 secciones (limite alcanzado para id_proyecto=1)


-- =====================================================================
-- CONSULTA 12: Intento de borrar la ultima seccion de un proyecto
-- (prueba del trigger trg_min_secciones)
-- Uso: prueba para demostrar que un proyecto nunca puede quedar sin
-- secciones. El proyecto 2 (Bot de Telegram) tiene 3 secciones
-- (id_seccion 5, 6 y 7 segun el dml.sql).
-- =====================================================================
-- DELETE FROM seccion WHERE id_seccion = 5;  -- OK, quedan 2
-- DELETE FROM seccion WHERE id_seccion = 6;  -- OK, queda 1
-- DELETE FROM seccion WHERE id_seccion = 7;  -- Debe fallar:
-- ERROR: Un proyecto no puede quedar sin secciones (minimo 1 requerido, id_proyecto=2)


-- =====================================================================
-- CONSULTA 13: Intento de que el dueño se auto-invite como colaborador
-- (prueba del trigger trg_no_autoinvitar)
-- Uso: prueba para demostrar que el dueño de un proyecto no puede
-- aparecer tambien como colaborador de su propio proyecto. Jefferson
-- (usuario 1) es el dueño del proyecto 1 segun el dml.sql.
-- =====================================================================
-- INSERT INTO colaborador_proyecto (id_proyecto, id_usuario) VALUES (1, 1);
-- Debe fallar con:
-- ERROR: El dueño del proyecto (usuario 1) no puede agregarse como colaborador
