-- =====================================================================
-- ProsperApp - DDL
-- Proyecto final - Bases de Datos
--
-- Este script crea las 9 tablas del sistema. La idea general es:
-- un Usuario tiene Proyectos (y puede colaborar en proyectos de otros
-- usuarios via colaborador_proyecto), cada Proyecto tiene un tablero
-- con Secciones (como Backlog, Doing, Completed...), cada Seccion tiene
-- Funcionalidades (las tarjetas/historias de usuario), y cada
-- Funcionalidad puede tener varias Subtareas, Notas de diseño,
-- Fragmentos de codigo y Decisiones tecnicas.
-- =====================================================================

-- Elimino las tablas si ya existen, para poder correr el script
-- varias veces mientras hago pruebas sin que me tire error de
-- "la tabla ya existe"
DROP TABLE IF EXISTS decision_tecnica CASCADE;
DROP TABLE IF EXISTS fragmento_codigo CASCADE;
DROP TABLE IF EXISTS nota_diseno CASCADE;
DROP TABLE IF EXISTS subtarea CASCADE;
DROP TABLE IF EXISTS funcionalidad CASCADE;
DROP TABLE IF EXISTS seccion CASCADE;
DROP TABLE IF EXISTS colaborador_proyecto CASCADE;
DROP TABLE IF EXISTS proyecto CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;

-- =====================================================================
-- 1. USUARIO
-- La tabla mas "de arriba" del modelo: todo proyecto le pertenece a
-- un usuario. Aqui simplificamos el manejo de roles a un solo campo
-- de texto (rol) en vez de crear una tabla Rol aparte
-- =====================================================================
CREATE TABLE usuario (
    id_usuario      SERIAL PRIMARY KEY,    
    nombre          VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,    
    rol             VARCHAR(20)  NOT NULL DEFAULT 'usuario'
                        CHECK (rol IN ('admin', 'usuario')), 
    fecha_registro  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================================
-- 2. PROYECTO
---- Cada proyecto le pertenece a un unico usuario dueño/creador (por
-- eso la FK id_usuario). Los colaboradores adicionales se manejan
-- aparte en la tabla colaborador_proyecto (ver seccion 2.1), para
-- no perder la nocion de quien es el dueño original del proyecto.
-- =====================================================================
CREATE TABLE proyecto (
    id_proyecto     SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado          VARCHAR(20) NOT NULL DEFAULT 'activo'
                        CHECK (estado IN ('activo', 'completado', 'archivado')),
    id_usuario      INT NOT NULL REFERENCES usuario(id_usuario)
                        ON DELETE CASCADE
);

-- =====================================================================
-- 2.1 COLABORADOR_PROYECTO (tabla puente para colaboradores)
-- Relacion muchos a muchos: un usuario puede colaborar en varios
-- proyectos y un proyecto puede tener varios colaboradores.
-- El dueño del proyecto sigue siendo proyecto.id_usuario; esta tabla
-- es solo para colaboradores adicionales invitados por el dueño.
-- =====================================================================
CREATE TABLE colaborador_proyecto (
    id_proyecto      INT NOT NULL REFERENCES proyecto(id_proyecto)
                         ON DELETE CASCADE,
    id_usuario       INT NOT NULL REFERENCES usuario(id_usuario)
                         ON DELETE CASCADE,
    rol_colaborador  VARCHAR(20) NOT NULL DEFAULT 'editor'
                         CHECK (rol_colaborador IN ('editor', 'lector')),
    fecha_union      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_proyecto, id_usuario)
);

-- =====================================================================
-- TRIGGER_COLABORADOR: impedir que el dueño de un proyecto se agregue a si mismo
-- como colaborador. El dueño ya tiene acceso total por ser
-- proyecto.id_usuario; no tiene sentido que tambien aparezca como
-- fila en colaborador_proyecto.
-- =====================================================================
CREATE OR REPLACE FUNCTION validar_no_autoinvitar()
RETURNS TRIGGER AS $$
DECLARE
    id_dueno INT;
BEGIN
    SELECT id_usuario INTO id_dueno
    FROM proyecto
    WHERE id_proyecto = NEW.id_proyecto;

    IF NEW.id_usuario = id_dueno THEN
        RAISE EXCEPTION 'El dueño del proyecto (usuario %) no puede agregarse como colaborador', id_dueno;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_autoinvitar
    BEFORE INSERT ON colaborador_proyecto
    FOR EACH ROW
    EXECUTE FUNCTION validar_no_autoinvitar();

-- =====================================================================
-- 3. SECCION (las columnas del tablero: Backlog, Doing, Completed...)
-- Se requieren minimo 1 y maximo 6 secciones por proyecto. Aqui viene
-- algo importante que aprendi haciendo este proyecto: un CHECK normal
-- (como "posicion_orden BETWEEN 1 AND 6") NO sirve para esto, porque
-- un CHECK solo mira los valores DE LA MISMA FILA que se esta
-- insertando, no puede contar cuantas filas relacionadas ya existen.
-- Por eso el limite de 6 secciones lo resuelvo mas abajo con un
-- TRIGGER, que si puede contar cuantas secciones tiene ya el proyecto
-- antes de dejar insertar una nueva.
-- =====================================================================
CREATE TABLE seccion (
    id_seccion      SERIAL PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    orden           INT NOT NULL CHECK (orden > 0), 
    id_proyecto     INT NOT NULL REFERENCES proyecto(id_proyecto)
                        ON DELETE CASCADE,
    CONSTRAINT uq_seccion_orden UNIQUE (id_proyecto, orden)
    -- esta restriccion evita que dentro del MISMO proyecto haya dos
    -- secciones con el mismo numero de orden (por ejemplo, dos
    -- columnas que digan "posicion 2")
);

-- =====================================================================
-- 4. FUNCIONALIDAD (la tarjeta/historia de usuario dentro de una seccion)
-- Esta es la tabla central del sistema. Cada funcionalidad vive en
-- una sola seccion a la vez -- cuando el usuario la mueve de Doing a
-- Completed, lo que pasa por detras es que se actualiza el valor de
-- id_seccion, no se crea un registro nuevo.
-- =====================================================================
CREATE TABLE funcionalidad (
    id_funcionalidad     SERIAL PRIMARY KEY,
    titulo               VARCHAR(150) NOT NULL,
    historia_usuario     TEXT,                   -- el clasico "Como... quiero... para..."
    descripcion_detallada TEXT,
    prioridad            VARCHAR(20) DEFAULT 'media'
                             CHECK (prioridad IN ('alta', 'media', 'baja')),
    orden                INT NOT NULL DEFAULT 0 CHECK (orden >= 0),  -- posicion de la tarjeta dentro de su columna
    fecha_creacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_seccion           INT NOT NULL REFERENCES seccion(id_seccion)
                             ON DELETE CASCADE
);

-- =====================================================================
-- 5. SUBTAREA (el checklist de una funcionalidad)
-- =====================================================================
CREATE TABLE subtarea (
    id_subtarea      SERIAL PRIMARY KEY,
    descripcion      VARCHAR(255) NOT NULL,
    completada       BOOLEAN NOT NULL DEFAULT FALSE, 
    orden            INT NOT NULL DEFAULT 0 CHECK (orden >= 0),
    id_funcionalidad INT NOT NULL REFERENCES funcionalidad(id_funcionalidad)
                         ON DELETE CASCADE
);

-- =====================================================================
-- 6. NOTA_DISENO
-- La separe en su propia tabla (en vez de una columna "notas" en
-- funcionalidad) justamente para poder guardar VARIAS notas por
-- funcionalidad, cada una con su propia fecha.
-- =====================================================================
CREATE TABLE nota_diseno (
    id_nota          SERIAL PRIMARY KEY,
    contenido        TEXT NOT NULL,
    fecha            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_funcionalidad INT NOT NULL REFERENCES funcionalidad(id_funcionalidad)
                         ON DELETE CASCADE
);

-- =====================================================================
-- 7. FRAGMENTO_CODIGO
-- Mismo razonamiento que nota_diseno: una funcionalidad puede tener
-- varios fragmentos de codigo, cada uno en un lenguaje distinto.
-- =====================================================================
CREATE TABLE fragmento_codigo (
    id_fragmento     SERIAL PRIMARY KEY,
    lenguaje         VARCHAR(50), 
    codigo           TEXT NOT NULL,
    descripcion      VARCHAR(255),
    id_funcionalidad INT NOT NULL REFERENCES funcionalidad(id_funcionalidad)
                         ON DELETE CASCADE
);

-- =====================================================================
-- 8. DECISION_TECNICA
-- Aqui guardo las decisiones tecnicas que se van tomando mientras se
-- desarrolla la funcionalidad, junto con la justificacion de por que
-- se tomo esa decision.
-- =====================================================================
CREATE TABLE decision_tecnica (
    id_decision      SERIAL PRIMARY KEY,
    descripcion      TEXT NOT NULL,
    justificacion    TEXT,
    fecha            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_funcionalidad INT NOT NULL REFERENCES funcionalidad(id_funcionalidad)
                         ON DELETE CASCADE
);

-- =====================================================================
-- TRIGGER_MAX_SECCIONES: limitar cada proyecto a un maximo de 6 secciones
-- =====================================================================
CREATE OR REPLACE FUNCTION validar_max_secciones()
RETURNS TRIGGER AS $$
DECLARE
    total_secciones INT;
BEGIN
    SELECT COUNT(*) INTO total_secciones
    FROM seccion
    WHERE id_proyecto = NEW.id_proyecto;

    IF total_secciones >= 6 THEN
        RAISE EXCEPTION 'Un proyecto no puede tener mas de 6 secciones (limite alcanzado para id_proyecto=%)', NEW.id_proyecto;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_secciones
    BEFORE INSERT ON seccion
    FOR EACH ROW
    EXECUTE FUNCTION validar_max_secciones();

-- =====================================================================
-- TRIGGER_MIN_SECCIONES: limitar cada proyecto a un minimo de 1 seccion
--
-- FIX (arreglado tras pruebas manuales): la primera version de este
-- trigger solo revisaba BEFORE DELETE ON seccion y contaba cuantas
-- secciones le quedaban al proyecto. Eso funcionaba bien si alguien
-- borraba una seccion suelta, PERO se rompia al borrar un PROYECTO
-- completo: el ON DELETE CASCADE de la FK proyecto->seccion dispara
-- un DELETE por cada seccion del proyecto, uno a uno, y ese DELETE
-- SI activa este mismo trigger BEFORE DELETE. Entonces, al llegar a
-- borrar la ultima seccion que le quedaba (porque las demas ya se
-- habian borrado en la misma cascada), el trigger la rechazaba con
-- "no puede quedar sin secciones" -- lo cual cancelaba el borrado
-- del PROYECTO completo, que era la operacion que el usuario si
-- queria hacer.
--
-- La solucion usa pg_trigger_depth(), una funcion de Postgres que
-- indica si el codigo actual esta corriendo anidado dentro de otro
-- trigger. Cuando se borra una seccion DIRECTAMENTE (DELETE FROM
-- seccion ...), este trigger corre en el primer nivel y SI debe
-- validar el minimo. Cuando el borrado viene EN CASCADA porque se
-- borro el proyecto (la cascada la dispara un trigger interno de
-- integridad referencial de Postgres), este trigger corre anidado
-- dentro de ese proceso, y en ese caso NO debe bloquear nada: la
-- intencion es borrar todo el proyecto, secciones incluidas.
-- =====================================================================
CREATE OR REPLACE FUNCTION validar_min_secciones()
RETURNS TRIGGER AS $$
DECLARE
    total_secciones INT;
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN OLD;
    END IF;

    SELECT COUNT(*) INTO total_secciones
    FROM seccion
    WHERE id_proyecto = OLD.id_proyecto;

    IF total_secciones <= 1 THEN
        RAISE EXCEPTION 'Un proyecto no puede quedar sin secciones (minimo 1 requerido, id_proyecto=%)', OLD.id_proyecto;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_min_secciones
    BEFORE DELETE ON seccion
    FOR EACH ROW
    EXECUTE FUNCTION validar_min_secciones();

-- =====================================================================
-- INDICES: estos no son obligatorios para que el modelo funcione,
-- pero los agrego porque el dashboard va a hacer consultas
-- frecuentes filtrando por estas columnas, y un indice hace que esas
-- busquedas sean mucho mas rapidas cuando haya muchos datos.
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_proyecto_usuario ON proyecto(id_usuario);
CREATE INDEX IF NOT EXISTS idx_seccion_proyecto ON seccion(id_proyecto);
CREATE INDEX IF NOT EXISTS idx_colaborador_usuario ON colaborador_proyecto(id_usuario);
CREATE INDEX IF NOT EXISTS idx_funcionalidad_seccion ON funcionalidad(id_seccion);
CREATE INDEX IF NOT EXISTS idx_subtarea_funcionalidad ON subtarea(id_funcionalidad);
CREATE INDEX IF NOT EXISTS idx_nota_funcionalidad ON nota_diseno(id_funcionalidad);
CREATE INDEX IF NOT EXISTS idx_fragmento_funcionalidad ON fragmento_codigo(id_funcionalidad);
CREATE INDEX IF NOT EXISTS idx_decision_funcionalidad ON decision_tecnica(id_funcionalidad);
