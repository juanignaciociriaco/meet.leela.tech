# meet.leela.tech

Despliegue de **Jitsi Meet** sobre Docker para `https://meet.leela.tech`, con branding personalizado de **LeelaTech** (paleta y tipografía tomadas de [leela.tech](https://leela.tech)).

Basado en [`docker-jitsi-meet`](https://github.com/jitsi/docker-jitsi-meet). El README original del upstream se conserva como [README.upstream.md](README.upstream.md).

---

## Stack

- Docker Compose (`docker-compose.yml`, `.env` en este directorio).
- Servicios principales: `web`, `prosody`, `jicofo`, `jvb`.
- Detrás de Cloudflare (TLS terminado en CF; el contenedor `web` sirve HTTP/HTTPS interno).
- Configuración persistente bind-mounteada desde:
  ```
  /root/.jitsi-meet-cfg/
  ├── web/                 # config del frontend
  │   ├── interface_config.js
  │   ├── custom-interface_config.js   # overrides de branding LeelaTech
  │   └── leelatech/                   # assets personalizados (fuente de verdad)
  │       ├── plugin.head.html         # CSS + JS inyectado en <head>
  │       ├── title.html               # <title> y meta tags
  │       ├── watermark.svg            # logo "leelatech" (Sora 800, fill #1f1e1d)
  │       └── lang/                    # main.json, main-es.json con textos LeelaTech
  ├── prosody/
  ├── jicofo/
  └── jvb/
  ```

---

## Branding LeelaTech

### Paleta (de `leela.tech`)

| Variable CSS         | Hex        | Uso                                    |
| -------------------- | ---------- | -------------------------------------- |
| `--lt-black`         | `#1f1e1d`  | Texto, logo, título                    |
| `--lt-black-low`     | `#686662`  | Texto secundario                       |
| `--lt-white`         | `#ffffff`  | Fondo principal                        |
| `--lt-gray`          | `#a59f96`  | Bordes / acentos suaves                |
| `--lt-gray-text`     | `#6a6a6a`  | Placeholder                            |
| `--lt-gray-low`      | `#e9e0d5`  | Bordes de cards / input                |
| `--lt-orange`        | `#eb5e28`  | CTA "Start meeting"                    |
| `--lt-orange-hover`  | `#d6501c`  | Hover del CTA                          |
| `--lt-blue`          | `#448dc1`  | Reservado                              |

### Tipografía

- **Display** (logo, título, botón): `Sora` (700–800) — vía Google Fonts.
- **Body**: `DM Sans` — vía Google Fonts.
- Las fuentes oficiales de leela.tech (Switzer, SF Pro) son comerciales; usamos Sora como reemplazo coherente (ya estaba en el logo).

### Welcome page

- Fondo blanco, sin imagen de espacio.
- Logo `leelatech` (SVG con Sora 800, fill `#1f1e1d`) arriba a la izquierda, `320×80px`.
- Título central: **"LeelaTech Meeting Platform"** (sustituido vía JS porque los strings del welcome page están baked-in en `app.bundle.min.js`).
- Subtítulo "Secure and high quality meetings" oculto.
- Input de sala: blanco con borde gris claro, texto negro, caret naranja.
- Botón "Start meeting": naranja LeelaTech con hover.
- Card de recent list: blanca con borde sutil.

---

## Archivos clave de branding

### 1. `/root/.jitsi-meet-cfg/web/leelatech/plugin.head.html`

Se inyecta en el `<head>` del `index.html` de Jitsi. Contiene:

- `<link>` a Google Fonts (Sora + DM Sans).
- `<style>` con variables `--lt-*` y todos los overrides visuales.
- `<script>` con un `MutationObserver` que fuerza `.header-text-title` a `"LeelaTech Meeting Platform"` (necesario porque editar `lang/main.json` no surte efecto: los strings están embebidos en el bundle).

### 2. `/root/.jitsi-meet-cfg/web/leelatech/watermark.svg`

SVG `320×80` con el texto `leelatech` en Sora 800, `fill: #1f1e1d`. Se sirve como `/images/watermark.svg` en el contenedor.

### 3. `/root/.jitsi-meet-cfg/web/leelatech/title.html`

`<title>` y meta OG/`itemprop` con "LeelaTech Meeting Platform".

### 4. `/root/.jitsi-meet-cfg/web/custom-interface_config.js`

Overrides agregados al final de `interface_config.js` por `cont-init.d/10-config`:

```js
interfaceConfig.APP_NAME = 'LeelaTech Meeting Platform';
interfaceConfig.NATIVE_APP_NAME = 'LeelaTech Meet';
interfaceConfig.PROVIDER_NAME = 'LeelaTech';
interfaceConfig.JITSI_WATERMARK_LINK = 'https://leela.tech';
interfaceConfig.DEFAULT_WELCOME_PAGE_LOGO_URL = 'images/watermark.svg?v=<ts>';
interfaceConfig.DEFAULT_LOGO_URL = 'images/watermark.svg?v=<ts>';
```

### 5. `/root/.jitsi-meet-cfg/web/leelatech/lang/{main,main-es}.json`

Traducciones con textos LeelaTech (`welcomepage.title`, `headerTitle`, `appDescription`, etc.). Útiles para el resto de la UI; el welcome page se override por JS porque el bundle tiene fallbacks embebidos.

---

## Cómo aplicar cambios de branding

Los archivos en `/root/.jitsi-meet-cfg/web/leelatech/` son **la fuente de verdad**. NO son auto-copiados al contenedor: hay que pusharlos manualmente con `docker cp`.

### Editar el CSS / JS del welcome page

```bash
# 1. Editar
vim /root/.jitsi-meet-cfg/web/leelatech/plugin.head.html

# 2. Copiar al contenedor (el "device or resource busy" es inocuo, el contenido se reemplaza)
docker cp /root/.jitsi-meet-cfg/web/leelatech/plugin.head.html \
  jitsi-meet_web_1:/usr/share/jitsi-meet/plugin.head.html

# 3. Verificar
curl -sk "https://meet.leela.tech/?z=$(date +%s%N)" | grep -A1 "LeelaTech"
```

### Cambiar el logo

```bash
vim /root/.jitsi-meet-cfg/web/leelatech/watermark.svg
docker cp /root/.jitsi-meet-cfg/web/leelatech/watermark.svg \
  jitsi-meet_web_1:/usr/share/jitsi-meet/images/watermark.svg

# Bump del cache-buster en interface_config:
V=$(date +%s)
sed -i "s|images/watermark.svg?v=[0-9]*|images/watermark.svg?v=$V|g" \
  /root/.jitsi-meet-cfg/web/custom-interface_config.js
sed -i "s|images/watermark.svg?v=[0-9]*|images/watermark.svg?v=$V|g" \
  /root/.jitsi-meet-cfg/web/leelatech/plugin.head.html
docker cp /root/.jitsi-meet-cfg/web/leelatech/plugin.head.html \
  jitsi-meet_web_1:/usr/share/jitsi-meet/plugin.head.html
```

### Cambiar el título del welcome page

Editar la línea en `plugin.head.html`:

```js
var DESIRED_TITLE = 'LeelaTech Meeting Platform';
```

Y re-pushar al contenedor.

### Cambiar `<title>` / meta tags

```bash
vim /root/.jitsi-meet-cfg/web/leelatech/title.html
docker cp /root/.jitsi-meet-cfg/web/leelatech/title.html \
  jitsi-meet_web_1:/usr/share/jitsi-meet/title.html
```

---

## Cache

Hay **dos capas de caché** que pueden tapar los cambios:

1. **Cloudflare** (sirve `meet.leela.tech`). Purgar:
   - Dashboard → Caching → Purge Everything, o por URL:
     `/`, `/plugin.head.html`, `/interface_config.js`, `/title.html`, `/images/watermark.svg`, `/lang/main.json`, `/lang/main-es.json`.
2. **Service Worker** del navegador (Jitsi registra uno y cachea agresivamente).
   - DevTools → Application → Service Workers → **Unregister**.
   - DevTools → Application → Storage → **Clear site data**.
   - O abrir en **modo incógnito**.

Para los assets de branding usamos cache-busters `?v=<timestamp>` en el URL del watermark, lo cual evita que CF sirva una versión vieja después de un cambio.

---

## Operaciones comunes

```bash
cd /root/jitsi-meet

# Levantar / reiniciar
docker compose up -d
docker compose restart web

# Reconstruir (si hay cambios en .env o imágenes)
./jitsi.sh rebuild      # o: docker compose down && docker compose up -d

# Logs
docker logs -f jitsi-meet_web_1
docker logs -f jitsi-meet_prosody_1
docker logs -f jitsi-meet_jicofo_1
docker logs -f jitsi-meet_jvb_1

# Entrar al contenedor web
docker exec -it jitsi-meet_web_1 sh
```

---

## ⚠️ Persistencia tras `rebuild`

Los archivos dentro del contenedor `jitsi-meet_web_1` en `/usr/share/jitsi-meet/` **no son persistentes**: vienen de la imagen. Tras un `down`/`rebuild` se pierden los `docker cp` manuales de:

- `plugin.head.html`
- `title.html`
- `images/watermark.svg`
- `lang/main.json`, `lang/main-es.json`

`interface_config.js` y `custom-interface_config.js` SÍ persisten porque `/config` está bind-mounteado.

### Re-aplicar branding tras un rebuild

```bash
SRC=/root/.jitsi-meet-cfg/web/leelatech
docker cp $SRC/plugin.head.html jitsi-meet_web_1:/usr/share/jitsi-meet/plugin.head.html
docker cp $SRC/title.html       jitsi-meet_web_1:/usr/share/jitsi-meet/title.html
docker cp $SRC/watermark.svg    jitsi-meet_web_1:/usr/share/jitsi-meet/images/watermark.svg
docker cp $SRC/lang/main.json   jitsi-meet_web_1:/usr/share/jitsi-meet/lang/main.json
docker cp $SRC/lang/main-es.json jitsi-meet_web_1:/usr/share/jitsi-meet/lang/main-es.json
```

> TODO: convertir esto en un `cont-init.d` script o un volumen bind para que se aplique automáticamente al levantar el contenedor.

---

## Verificación rápida

```bash
# Branding inyectado en HTML
curl -sk "https://meet.leela.tech/?z=$(date +%s%N)" | grep -E "LeelaTech|--lt-orange|DESIRED_TITLE" | head

# Watermark servido
curl -sk "https://meet.leela.tech/images/watermark.svg?z=$(date +%s%N)" | grep fill

# interface_config overrides
curl -sk "https://meet.leela.tech/interface_config.js?z=$(date +%s%N)" | tail -10
```

---

## Referencias

- Upstream: https://github.com/jitsi/docker-jitsi-meet
- Paleta y fuentes: https://leela.tech (CSS en `/_next/static/css/`)
- README upstream original: [README.upstream.md](README.upstream.md)
