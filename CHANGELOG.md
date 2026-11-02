# CHANGELOG

## 2026.11 — HTTPS C2 / Stage-0

### Added

- `-X` control plane: `build`, `server`, `ctl`, `fingerprint`, `deploy`,
  `stage`.
- `king/c2/`:
  - `c2_common.py` — HMAC signing, replay cache, sealed-blob helpers;
  - `c2_pack.py` — PKI, secrets, module sealing, stage-0 rendering;
  - `c2_server.py` — HTTPS listener, task queue, loot, admin API;
  - `c2_ctl.py` — operator CLI;
  - `c2_implant.py` — minimal stage-0 template;
  - `modules/` — `recon`, `persist`, `shadow`, `wall`, `capture`, `troll`,
    `diamorphine`.
- TLS 1.2+ with CA and SHA256 fingerprint pinning.
- HMAC-SHA256 request signing over method, path, timestamp, nonce and body
  hash; 5-minute skew; replay-protected nonce cache.
- Optional mTLS with a client certificate signed by the pinned CA.
- Sealed modules executed from memory (`/bin/sh -s`, `python3 -`, `memfd`).
- Modular loading: startup set at build time, runtime `add-module`, task
  queue, `upload` / `download` / `loot`.
- Diamorphine wrapper: builds/loads upstream LKM, patches `MAGIC_PREFIX` to
  `blk_`, installs boot persistence, supports `status | unload | hide-pid |
  give-root | toggle`.
- Secret scoping: `BW_SECRET_B64`, `BW_CA_PEM_B64`, `BW_FINGERPRINT` only
  for modules declaring `# SECRET: 1` (`persist`).
- Default artefact root `BW_PREFIX_DIR=/usr/local/sbin/blk_kit`; dry-run
  redirects it to `/tmp/blackwall-c2-dry`.
- Themed C2 output: coloured `[C2]`, banners, AI quotes in build/server/
  stage/ctl and `-B`.
- Detailed docs: `king/c2/README.md`, README update, this changelog.

### Fixed

- `-B` quick audit bottom border used an undefined `${TXT_}` variable and
  rendered uncoloured; now uses `${TXT_VOID}` and prints a closing quote.
- `server.json.key` could be clobbered by the `--env` parser in the builder.
- `/api/v1/result` now includes `session`, so per-task results are applied
  immediately instead of waiting for the next beacon.
- mTLS server certificate now carries `serverAuth,clientAuth` EKU so it can
  act as the CA for implant client certificates.
- C2 server log filters high-frequency beacon/task polling while keeping
  registrations, module pulls and errors.

### Verified

- Local HTTPS server + stage-0 registration.
- `shell`, `recon`, runtime `add-module`.
- `upload` / `download` / `loot`.
- mTLS handshake and operator CLI with a client certificate.
- Dry-run module execution.
- `bash -n`, `dash -n`, `py_compile`, `git diff --check`.
