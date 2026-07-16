// service-worker.js
// Cachea el archivo principal de la app y los assets propios (iconos,
// manifest) para que cargue rapido en visitas futuras. Las llamadas a
// la API (fetch hacia /api/...) NUNCA se cachean: los datos del
// tablero cambian todo el tiempo y siempre deben pedirse frescos al
// backend.

const CACHE_NAME = "prosperapp-shell-v1";

const ARCHIVOS_DEL_SHELL = [
  "/prosperapp_spa.html",
  "/manifest.json",
  "/icon-192.png",
  "/icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ARCHIVOS_DEL_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((nombres) =>
      Promise.all(
        nombres
          .filter((nombre) => nombre !== CACHE_NAME)
          .map((nombre) => caches.delete(nombre))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // Las peticiones a la API del backend siempre van directo a la red.
  if (url.pathname.startsWith("/api/")) {
    event.respondWith(fetch(event.request));
    return;
  }

  // Solo intenta servir desde cache los archivos que son del mismo
  // origen (el propio HTML, manifest, iconos). Los CDN externos
  // (Tailwind, FontAwesome, Google Fonts) se dejan pasar directo a
  // la red, tal cual, sin interceptarlos.
  if (url.origin !== self.location.origin) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((respuestaCacheada) => {
      return respuestaCacheada || fetch(event.request);
    })
  );
});
