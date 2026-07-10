-- =====================================================================
-- ProsperApp - Consultas de la aplicacion
-- Proyecto final - Bases de Datos
--
-- Este script agrupa las consultas SQL que la aplicacion necesitaria
-- ejecutar en su uso diario: cargar el tablero de un proyecto, calcular
-- el progreso, traer la "ficha" completa de una funcionalidad, etc.
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
-- CONSULTA 5: Funcionalidades de alta prioridad pendientes por usuario
-- Uso en la app: seccion "Mis pendientes urgentes" del dashboard.
-- Recorre toda la cadena usuario -> proyecto -> seccion -> funcionalidad
-- para encontrar las tarjetas de prioridad alta que no estan todavia
-- en la ultima seccion (es decir, que no estan "terminadas").
-- =====================================================================
SELECT
    u.nombre        AS usuario,
    p.nombre        AS proyecto,
    s.nombre        AS seccion_actual,
    f.titulo,
    f.prioridad
FROM usuario u
JOIN proyecto p       ON p.id_usuario = u.id_usuario
JOIN seccion s        ON s.id_proyecto = p.id_proyecto
JOIN funcionalidad f  ON f.id_seccion = s.id_seccion
WHERE f.prioridad = 'alta'
  AND s.orden < (SELECT MAX(s2.orden) FROM seccion s2 WHERE s2.id_proyecto = p.id_proyecto)
ORDER BY u.nombre, p.nombre;


-- =====================================================================
-- CONSULTA 6: Mover una funcionalidad de seccion (drag and drop)
-- Uso en la app: cuando el usuario arrastra una tarjeta de una columna
-- a otra. Como se explico en el DDL, esto es un UPDATE del campo
-- id_seccion, no la creacion de una fila nueva.
-- =====================================================================
UPDATE funcionalidad
SET id_seccion = 2   -- id de la seccion destino (ej. "Doing")
WHERE id_funcionalidad = 4;


-- =====================================================================
-- CONSULTA 7 (TRANSACCION): crear un proyecto junto con su seccion
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
-- CONSULTA 8: Intento de insertar una septima seccion (prueba del trigger)
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
