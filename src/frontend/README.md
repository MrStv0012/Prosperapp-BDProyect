# Frontend — ProsperApp SPA

Interfaz de usuario construida como una **SPA de un solo archivo HTML**, sin frameworks de frontend: HTML + Tailwind CSS (vía CDN) + JavaScript vanilla, consumiendo la API del backend con `fetch`.

---

## 🧱 Stack

| Herramienta | Uso |
|---|---|
| Tailwind CSS (CDN) | Estilos |
| Font Awesome (CDN) | Iconografía |
| JavaScript vanilla | Lógica de la aplicación, manejo de estado y llamadas a la API |
| `localStorage` | Persiste el token JWT y los datos del usuario entre recargas de página |

No requiere build ni bundler: es un único archivo `prosperapp_spa.html` que el navegador ejecuta directamente.

---

## ▶️ Cómo levantarlo

El backend debe estar corriendo primero (por defecto en `http://localhost:3000`, configurado en la constante `API_BASE_URL` dentro del HTML).

Sirve el archivo con cualquier servidor estático simple (evita abrirlo con doble clic para prevenir restricciones del navegador con `file://`):

```bash
cd src/frontend
npx serve .
# o alternativamente:
python3 -m http.server 8080
```

Abre la URL que indique la terminal (ej. `http://localhost:5000` o `http://localhost:8080`).

---

## 🖥️ Pantallas

| Vista | Descripción |
|---|---|
| Login / Registro | Autenticación de usuarios contra `/api/auth` |
| Dashboard | Lista de "mis proyectos" (dueño o colaborador) con indicador de progreso |
| Tablero Kanban | Secciones como columnas, funcionalidades como tarjetas, con drag and drop |
| Detalle de tarjeta | Historia de usuario, checklist de subtareas, notas de diseño, fragmentos de código y decisiones técnicas |
| Colaboradores | Listado e invitación de colaboradores por proyecto |

---

## 🔄 Modo Demo vs. Base de datos real

El header incluye un selector **Modo Demo (DML)** / **BD PostgreSQL Real**. En modo demo, la interfaz se puede explorar con datos de ejemplo cargados en el propio JavaScript, sin necesidad del backend — útil para una vista rápida sin levantar Docker. En modo BD real, todas las acciones llaman a la API y persisten en PostgreSQL.

---

## ⚙️ Configuración

Si el backend corre en otra URL o puerto, ajusta la constante al inicio del `<script>`:

```javascript
const API_BASE_URL = 'http://localhost:3000/api';
```
