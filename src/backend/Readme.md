# Backend — ProsperApp API

API REST construida con **Node.js + Express**, conectada directamente a la base de datos PostgreSQL mediante consultas parametrizadas (`pg`).

---

## 🧱 Stack

| Herramienta | Uso |
|---|---|
| Express | Framework del servidor HTTP y enrutamiento |
| pg (node-postgres) | Cliente de PostgreSQL, con pool de conexiones |
| bcryptjs | Hash de contraseñas |
| jsonwebtoken | Autenticación basada en tokens JWT |
| cors | Habilita peticiones desde el frontend |
| dotenv | Carga las variables de entorno desde `.env` |

---

## ▶️ Cómo levantarlo

1. Asegúrate de que la base de datos ya esté corriendo (ver `docker-compose.yml` en la raíz del repo).
2. Instala las dependencias:
   ```bash
   cd src/backend
   npm install
   ```
3. Copia `.env.example` (raíz del repo) a un `.env` accesible para este proceso y ajusta `DATABASE_URL` si es necesario.
4. Levanta el servidor:
   ```bash
   npm start
   ```
   Por defecto corre en `http://localhost:3000`.

---

## 🔑 Autenticación

Todas las rutas, salvo `/api/auth/register` y `/api/auth/login`, requieren un header:

```
Authorization: Bearer <token>
```

El token se obtiene al iniciar sesión y expira a las 24 horas. El middleware `authenticateToken` lo valida en cada petición protegida.

---

## 🛡️ Autorización por proyecto

Además de estar autenticado, un usuario solo puede leer o modificar datos de un proyecto si es su **dueño** o su **colaborador**. Esto se controla con el middleware `verificarAccesoProyecto`, aplicado a todos los endpoints que tocan secciones, funcionalidades, subtareas, notas, fragmentos de código, decisiones técnicas y colaboradores de un proyecto específico. Un usuario autenticado que intente acceder a un proyecto ajeno recibe `403 Forbidden`.

---

## 🗺️ Endpoints principales

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/register` | Crea un usuario nuevo (rol siempre `usuario`, no configurable desde el cliente) |
| POST | `/api/auth/login` | Inicia sesión y devuelve un JWT |
| GET | `/api/proyectos` | Proyectos accesibles por el usuario (dueño o colaborador), con % de avance |
| POST | `/api/proyectos` | Crea un proyecto junto con sus secciones iniciales (transacción) |
| GET | `/api/proyectos/:id/tablero` | Tablero completo: secciones + funcionalidades con conteo de subtareas |
| GET | `/api/pendientes` | Funcionalidades de prioridad alta pendientes del usuario |
| POST | `/api/secciones` | Crea una sección (sujeta a los triggers de mínimo/máximo de la BD) |
| DELETE | `/api/secciones/:id` | Elimina una sección (sujeta al trigger de mínimo de la BD) |
| POST | `/api/funcionalidades` | Crea una tarjeta/funcionalidad |
| GET | `/api/funcionalidades/:id` | Ficha completa de una tarjeta (notas, código, decisiones, subtareas) |
| PUT | `/api/funcionalidades/:id/mover` | Mueve una tarjeta entre secciones (drag and drop) |
| POST | `/api/funcionalidades/:id/subtareas` | Agrega una subtarea al checklist |
| PUT | `/api/subtareas/:id/toggle` | Marca/desmarca una subtarea |
| POST | `/api/funcionalidades/:id/notas` | Agrega una nota de diseño |
| POST | `/api/funcionalidades/:id/fragmentos` | Agrega un fragmento de código |
| POST | `/api/funcionalidades/:id/decisiones` | Agrega una decisión técnica |
| GET | `/api/proyectos/:id/colaboradores` | Lista los colaboradores de un proyecto |
| POST | `/api/proyectos/:id/colaboradores` | Invita a un usuario como colaborador |

---

## ⚠️ Manejo de errores de la base de datos

La función `handleDatabaseError` traduce los errores técnicos de PostgreSQL a mensajes legibles para el usuario final, incluyendo los 3 triggers de reglas de negocio definidos en el esquema:

- `trg_max_secciones` → máximo 6 secciones por proyecto.
- `trg_min_secciones` → mínimo 1 sección por proyecto.
- `trg_no_autoinvitar` → el dueño de un proyecto no puede ser también su colaborador.

También traduce violaciones de restricciones únicas (`23505`) y de `CHECK` (`23514`) definidas en `database/ddl.sql`.
