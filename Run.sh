#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Si no existe .env, crear desde ejemplo y generar passwords
if [[ ! -f .env ]]; then
    echo "[*] Creando .env desde env.example..."
    cp env.example .env
    echo "[*] Generando passwords..."
    bash ./gen-passwords.sh
fi

# Crear directorios de config si no existen
source .env 2>/dev/null || true
CONFIG="${CONFIG:-~/.jitsi-meet-cfg}"
CONFIG=$(eval echo "$CONFIG")
mkdir -p "$CONFIG"/{web/crontabs,web/load-test,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb}

echo "[*] Levantando Jitsi Meet..."
docker-compose up -d

echo ""
echo "[*] Estado de los servicios:"
docker-compose ps

echo ""
echo "========================================="
echo " Jitsi Meet corriendo"
echo " HTTP:  http://localhost:${HTTP_PORT:-8000}"
echo " HTTPS: https://localhost:${HTTPS_PORT:-8443}"
echo " JVB UDP: ${JVB_PORT:-10000}"
if [[ -n "${PUBLIC_URL:-}" ]]; then
    echo " Public URL: $PUBLIC_URL"
fi
echo "========================================="
