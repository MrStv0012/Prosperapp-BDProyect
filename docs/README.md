# Documentación — ProsperApp

Diagramas del diseño de la base de datos.

---

## 📄 Contenido

| Archivo | Descripción |
|---|---|
| `Modelo E-R.png` | Diagrama entidad-relación: las 9 tablas con sus atributos, claves y relaciones (notación pata de gallina) |
| `Modelo Relacional.png` | Mismo modelo, con las tablas distribuidas para apreciar la estructura de columnas de cada una |

---

## 🔄 Cómo regenerarlos

Ambos diagramas se generan desde el mismo código fuente en formato **DBML**, en [dbdiagram.io](https://dbdiagram.io/d).

1. Abre [dbdiagram.io/d](https://dbdiagram.io/d) y crea un diagrama nuevo.
2. Pega el contenido de `modelo.dbml` (ver raíz del repo o pedirlo de nuevo si no está en el repo) en el editor.
3. Exporta a PNG desde **Export → Export to PNG**.
4. Para la versión "Modelo Relacional", separa un poco más las cajas de las tablas antes de exportar, para que la vista enfatice las columnas por encima de las líneas de relación.

El DBML se mantiene sincronizado manualmente con `database/ddl.sql`: cada vez que se agregue o modifique una tabla, columna, o relación en el DDL, se debe actualizar el `.dbml` y regenerar ambas imágenes.
