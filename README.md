# ProsperApp - Software para Proyectos de Software Personales

ProsperApp es una herramienta diseñada para facilitar la planificación, diseño y desarrollo de proyectos de software personales. Permite a los desarrolladores organizar sus ideas mediante tableros visuales interactivos, estructurar historias de usuario (funcionalidades) y documentar notas de diseño, fragmentos de código, checklists de subtareas y decisiones técnicas clave en un solo lugar.

Este proyecto se desarrolla en el marco del curso de **Bases de Datos** de la **Escuela de Ingeniería de Sistemas y Computación** de la **Universidad del Valle**, bajo la dirección del docente **Jefferson A. Peña Torres**.

---

## 👥 Integrantes del Equipo
*   **Jhon Steven Angulo Nieves** - 2415995
*   **Juan Camilo Portilla** - 2418800
*   **Javier Alexander Ramirez** - 2325151

---

## 🚀 Descripción de la Plataforma
Desde la vista principal, la herramienta ofrece un panel (*dashboard*) con indicadores de progreso y tareas pendientes de los proyectos activos. 

Cada proyecto se representa como un tablero compuesto por secciones (columnas de estado: *Backlog*, *Doing*, *Completed*, etc.). El sistema limita dinámicamente el número de secciones a un **mínimo de una (1) y un máximo de seis (6)**. Dentro de cada sección se crean tarjetas correspondientes a las funcionalidades (historias de usuario), las cuales admiten descripciones detalladas, checklists de subtareas, notas de diseño, fragmentos de código en múltiples lenguajes y registro de decisiones técnicas con su respectiva justificación.

---

## 🗄️ Diseño de la Base de Datos
La persistencia de datos se maneja mediante un motor relacional **PostgreSQL**. El esquema consta de 8 tablas principales relacionadas entre sí:

1.  **`usuario`**: Registro de usuarios y roles básicos ('admin', 'usuario').
2.  **`proyecto`**: Información del proyecto y su respectivo dueño.
3.  **`seccion`**: Columnas configurables asociadas a un proyecto específico.
4.  **`funcionalidad`**: Tarjeta o historia de usuario dentro de una sección.
5.  **`subtarea`**: Checklist detallado para cada funcionalidad.
6.  **`nota_diseno`**: Notas de diseño de arquitectura o interfaz.
7.  **`fragmento_codigo`**: Snippets de código asociados a las soluciones técnicas.
8.  **`decision_tecnica`**: Historial de decisiones tomadas y su respectiva justificación.

### Triggers y Restricciones Relevantes
*   **Restricción de orden único**: Se implementó una restricción única compuesta (`uq_seccion_orden`) en la tabla `seccion` para garantizar que un mismo proyecto no posea dos columnas con el mismo número de orden asignado.
*   **Trigger de límite de secciones (`trg_max_secciones`)**: Dado que una validación `CHECK` estándar no puede evaluar registros de otras filas, se implementó una función y un disparador `BEFORE INSERT` que cuenta el número de secciones existentes en el proyecto antes de permitir el registro de una nueva, previniendo exceder el límite establecido de seis (6) secciones.
