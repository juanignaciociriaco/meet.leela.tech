#!/usr/bin/env bash
# Manejo manual del stack de Jitsi Meet (Docker).
# Uso:
#   ./jitsi.sh up         -> levanta los contenedores (sin tocar imagenes)
#   ./jitsi.sh down       -> baja y elimina contenedores (mantiene volumenes/configs)
#   ./jitsi.sh restart    -> down + up
#   ./jitsi.sh rebuild    -> down + pull de imagenes nuevas + up (datos persisten)
#   ./jitsi.sh status     -> estado de los contenedores
#   ./jitsi.sh logs [svc] -> tail -f de logs (web|prosody|jicofo|jvb). Sin svc => todos
#   ./jitsi.sh adduser U  -> crea usuario admin U@meet.jitsi (pide password)
#   ./jitsi.sh deluser U  -> borra usuario U@meet.jitsi
#   ./jitsi.sh passwd  U  -> cambia password de U@meet.jitsi
#   ./jitsi.sh users      -> lista usuarios admin registrados

set -euo pipefail
cd "$(dirname "$0")"

DC="docker-compose"
PROSODY="jitsi-meet_prosody_1"
PROSODY_CFG="/config/prosody.cfg.lua"
XMPP_DOMAIN="meet.jitsi"

ensure_env() {
    if [[ ! -f .env ]]; then
        echo "[*] No existe .env, lo creo desde env.example y genero passwords..."
        cp env.example .env
        bash ./gen-passwords.sh
    fi
    # shellcheck disable=SC1091
    source .env 2>/dev/null || true
    CONFIG="${CONFIG:-$HOME/.jitsi-meet-cfg}"
    CONFIG=$(eval echo "$CONFIG")
    mkdir -p "$CONFIG"/{web/crontabs,web/load-test,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb}
}

banner() {
    echo
    echo "========================================="
    echo " Jitsi Meet"
    echo " HTTP:       http://localhost:${HTTP_PORT:-8000}"
    echo " HTTPS:      https://localhost:${HTTPS_PORT:-8443}"
    echo " JVB UDP:    ${JVB_PORT:-10000}"
    [[ -n "${PUBLIC_URL:-}" ]] && echo " Public URL: $PUBLIC_URL"
    [[ -n "${JVB_ADVERTISE_IPS:-}" ]] && echo " JVB IPs:    $JVB_ADVERTISE_IPS"
    echo "========================================="
}

cmd_up()      { ensure_env; echo "[*] up -d"; $DC up -d; $DC ps; banner; }
cmd_down()    { echo "[*] down";    $DC down; }
cmd_restart() { cmd_down; cmd_up; }
cmd_rebuild() {
    ensure_env
    echo "[*] down"; $DC down
    echo "[*] pull"; $DC pull
    echo "[*] up -d"; $DC up -d
    $DC ps
    banner
}
cmd_status()  { $DC ps; }
cmd_logs()    { if [[ $# -gt 0 ]]; then $DC logs -f --tail=100 "$1"; else $DC logs -f --tail=50; fi; }

cmd_adduser() {
    [[ $# -ge 1 ]] || { echo "uso: $0 adduser USER"; exit 1; }
    docker exec -it "$PROSODY" prosodyctl --config "$PROSODY_CFG" register "$1" "$XMPP_DOMAIN"
}
cmd_deluser() {
    [[ $# -ge 1 ]] || { echo "uso: $0 deluser USER"; exit 1; }
    docker exec -it "$PROSODY" prosodyctl --config "$PROSODY_CFG" deluser "$1@$XMPP_DOMAIN"
}
cmd_passwd() {
    [[ $# -ge 1 ]] || { echo "uso: $0 passwd USER"; exit 1; }
    docker exec -it "$PROSODY" prosodyctl --config "$PROSODY_CFG" passwd "$1@$XMPP_DOMAIN"
}
cmd_users() {
    CONFIG="${CONFIG:-$HOME/.jitsi-meet-cfg}"
    CONFIG=$(eval echo "$CONFIG")
    local dir="$CONFIG/prosody/config/data/meet%2ejitsi/accounts"
    if [[ -d "$dir" ]]; then
        ls "$dir" | sed 's/%2e/./g; s/\.dat$//'
    else
        echo "(sin usuarios registrados)"
    fi
}

action="${1:-up}"; shift || true
case "$action" in
    up)        cmd_up ;;
    down)      cmd_down ;;
    restart)   cmd_restart ;;
    rebuild)   cmd_rebuild ;;
    status|ps) cmd_status ;;
    logs)      cmd_logs "$@" ;;
    adduser)   cmd_adduser "$@" ;;
    deluser)   cmd_deluser "$@" ;;
    passwd)    cmd_passwd "$@" ;;
    users)     cmd_users ;;
    -h|--help|help)
        sed -n '2,15p' "$0" ;;
    *)
        echo "Comando desconocido: $action"
        sed -n '2,15p' "$0"
        exit 1 ;;
esac
