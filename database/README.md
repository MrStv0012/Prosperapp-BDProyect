# Base de Datos — ProsperApp

Esquema relacional en **PostgreSQL**. Contiene 3 scripts que se ejecutan en orden.

---

## 📄 Archivos

| Archivo | Contenido |
|---|---|
| `ddl.sql` | Crea las 9 tablas, restricciones (`CHECK`, `UNIQUE`), triggers e índices |
| `dml.sql` | Datos de prueba: usuarios, proyectos, secciones, funcionalidades, subtareas, notas, fragmentos de código, decisiones técnicas y colaboradores |
| `queries.sql` | Las 13 consultas que usa la aplicación (tablero, progreso, checklist, ficha completa, proyectos accesibles, pendientes, colaboradores, transacción de creación, y pruebas comentadas de los 3 triggers) |

**Orden de ejecución:** `ddl.sql` → `dml.sql`. `queries.sql` se corre después, solo para consulta o pruebas manuales — no forma parte del setup inicial.

Si usas el `docker-compose.yml` de la raíz del repo, `ddl.sql` y `dml.sql` se ejecutan automáticamente al crear el contenedor por primera vez; no hace falta correrlos a mano.

---

## 🧩 Esquema (9 tablas)

| Tabla | Rol |
|---|---|
| `usuario` | Cuentas de la plataforma (rol global `admin`/`usuario`) |
| `proyecto` | Proyecto personal, con su dueño (`id_usuario`) |
| `colaborador_proyecto` | Tabla puente muchos-a-muchos: colaboradores adicionales de un proyecto, con rol local (`editor`/`lector`) |
| `seccion` | Columnas del tablero Kanban (Backlog, Doing, Completed...) |
| `funcionalidad` | Tarjetas / historias de usuario dentro de una sección |
| `subtarea` | Checklist de una funcionalidad |
| `nota_diseno` | Notas de diseño de una funcionalidad (varias por tarjeta) |
| `fragmento_codigo` | Snippets de código asociados a una funcionalidad |
| `decision_tecnica` | Decisiones técnicas con su justificación |

---

## ⚙️ Reglas de negocio implementadas con triggers

Un `CHECK` normal solo puede validar valores de la misma fila que se inserta; estas 3 reglas necesitan contar o consultar otras filas, por eso están resueltas con triggers en PL/pgSQL:

| Trigger | Evento | Regla |
|---|---|---|
| `trg_max_secciones` | `BEFORE INSERT` en `seccion` | Un proyecto no puede tener más de 6 secciones |
| `trg_min_secciones` | `BEFORE DELETE` en `seccion` | Un proyecto no puede quedar con 0 secciones |
| `trg_no_autoinvitar` | `BEFORE INSERT` en `colaborador_proyecto` | El dueño de un proyecto no puede agregarse a sí mismo como colaborador |

## ✅ Restricciones adicionales

- `uq_seccion_orden`: dentro de un mismo proyecto, no puede haber dos secciones con el mismo `orden`.
- `CHECK (orden > 0)` en `seccion`, `CHECK (orden >= 0)` en `funcionalidad` y `subtarea`: impiden valores de orden negativos (o cero, en el caso de secciones).
- Todas las claves foráneas usan `ON DELETE CASCADE`: borrar un usuario, proyecto, sección o funcionalidad elimina en cascada todo lo que depende de ella.

---

## 🚀 Índices

Se indexaron todas las columnas de clave foránea usadas en los `JOIN`/`WHERE` de `queries.sql` (`id_usuario`, `id_proyecto`, `id_seccion`, `id_funcionalidad` en sus respectivas tablas satélite), ya que PostgreSQL no crea índices automáticos sobre FKs, solo sobre la clave primaria.

---

## ▶️ Cómo correrlo manualmente (sin Docker)

```bash
psql -U postgres -d prosperapp -f ddl.sql
psql -U postgres -d prosperapp -f dml.sql
```
