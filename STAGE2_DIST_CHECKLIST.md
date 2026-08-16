# stage2 distribution — working checklist

> **TEMPORARY working doc — delete before merging `stage2-dist` to `master`.**
> Tracks turning the stage2 musl-hosted prefix into clean, distributable
> per-target packages. No absolute paths / hostnames / IPs in this file
> (it's committed to a public fork).

## Goal

One canonical stage2 build per target → two `tar.zst` artifacts, serving both
a public GitHub release and a mise `http`-backend index from the **same bytes**.

## Settled design

- **Two artifacts per target, one build, two cheap activations:**
  - `musl-cross-<target>.tar.zst` — canonical real ELF, `PT_INTERP` neutralized,
    ships `relocate`; `relocate --native` (patchelf → real abs interp) runs once
    (mise `postinstall`, or a human). Pristine ELF, correct identity.
  - `musl-cross-<target>-portable.tar.zst` — compiled static-musl launcher
    wrappers baked in; runs on extract, no step. The "mise unavailable" fallback.
- **Format:** standard `tar.zst` + `sha256` + `size`, pinned inline in a
  committed `mise.toml` (reviewable). `mise.lock` = version pin.
- **Template:** mise URL uses `{{ version }}` (spaced/Tera) — NOT `{{version}}`
  (parses as legacy `{version}`, removed in mise 2027.3.0).
- **Host arch** = URL platform (linux-x64 today); **target triple** lives in the
  tool NAME, not the platforms table.

## mise POC — DONE ✅ (hermetic stand-in, 11/11)

Proven on mise 2026.8.6: http backend from static URL · sha256+size enforced
(bad hash rejected) · strip_components · bin_path→PATH · **per-tool `postinstall`
runs inside the extracted tree with `MISE_TOOL_INSTALL_PATH`** (the linchpin that
lets mise auto-run `relocate --native`). Backend risk retired.

---

## Slice 1 — canonical clean tree  ← THIS SLICE

Produce a stripped, path-neutral, per-target tree. No launcher / packaging yet.

- [ ] **Per-target output**: `presets/stage2` → `OUTPUT = $(CURDIR)/dist/$(TARGET)`
      (kills the shared `output-stage2/` collision + stale-file gotcha; `dist/`
      already gitignored).
- [ ] **Strip host tools**: new `stage2/strip-host` script — strip ELF execs +
      host `.so` under `bin/`, `libexec/`, `<triple>/bin/` ONLY. Leave the target
      sysroot (`<triple>/lib`, `<triple>/include`, `lib/gcc/<triple>`) untouched.
      Invoked from the Makefile install rule BEFORE relocate.
- [ ] **Neutralize `PT_INTERP`** in `stage2/relocate`: patchelf
      `--set-interpreter /lib/<ld-musl-name>` on each `.real` (pairs with the
      existing `--remove-rpath`). Require patchelf (fail-fast if absent) for the
      stage2 path — stop shipping a `$HOME` path in binaries.
- [ ] **Validate** on x86_64-stage2 via install-only rebuild (build objects
      exist → fast): `./configure x86_64-stage2 && make install`, then
      `./run-tests --toolchain dist/x86_64-linux-musl` (expect 12/12) and
      `./run-caps --toolchain dist/x86_64-linux-musl` (expect 11 pass / 1 skip).
- [ ] **Check**: `readelf -l` on a `.real` shows no `$HOME`; `du -sh dist/<triple>`
      is a few hundred MB (was ~contributing to 13 GB shared tree); `file gcc`
      still a trampoline for now (fixed in Slice 2).

Acceptance: one clean per-target tree, no path leak, gates green, size sane.

## Slice 2 — relocation modes

- [ ] `relocate --native` (patchelf abs interp on real ELF, no wrappers) —
      idempotent; the mise/clean path.
- [ ] Compiled **static-musl launcher** replacing the `/bin/sh` trampoline for
      portable mode (fixes `file gcc`=script + per-compile shell-fork storm).
- [ ] Recover hard-link dedup (relink identical `.real`, or share one per group).

## Slice 3 — package driver

- [ ] Strip (Slice 1) → relink dupes → emit BOTH `tar.zst` (native + portable)
      per target + `SHA256SUMS` + provenance manifest.
- [ ] Emit the `mise.toml` snippet (`{{ version }}`, inline checksum+size,
      `postinstall = relocate --native`).

## Slice 4 — integration

- [ ] Lift `relocate` out of `make install` into the build-all/package driver.
- [ ] `build-all` loop: presets → `dist/<triple>` → run-tests + run-caps gate →
      package. (Folds in the existing installer/uninstaller roadmap.)

## Slice 5 — consume + docs

- [ ] Publish path (GitHub release asset + static bin index) — pick per class.
- [ ] devstack `TOOL_DISTRIBUTION.md`: fix `{{ version }}`, document the
      two-artifact model + `postinstall` relocate; doctor hook.

---

## Decisions / notes

- musl-dynamic host tools (NOT static): static musl can't `dlopen` →
  no `liblto_plugin.so` → no LTO/gcc-ar. Non-negotiable.
- `/proc/self/exe` is wrong under ANY wrapper (trampoline or launcher) — inherent;
  it's why `--native` (real ELF exec'd directly) is the clean default.
- Strip scope excludes target libs so users can still debug their own static
  binaries built against this toolchain.
- **TODO propose**: add a `SENSITIVE.md` (none today) — artifacts must carry no
  `$HOME`/build paths in `PT_INTERP`/RPATH and no internal index host/IP; give a
  compliance check (`readelf`-based interp/rpath scan of a packaged tree).
