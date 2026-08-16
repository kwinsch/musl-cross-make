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

## Slice 1 — canonical clean tree  ✅ DONE (x86_64-stage2 validated)

Stripped, path-neutral, per-target tree.

- [x] **Per-target output**: `presets/stage2` → `OUTPUT = $(CURDIR)/dist/$(TARGET)`.
- [x] **Strip host tools**: new `stage2/strip-host` (strip ELF execs + host `.so`
      under `bin/`, `libexec/`, `<triple>/bin/` only; target sysroot untouched;
      prefers stage1 strip). Runs BEFORE relocate in the Makefile install rule.
- [x] **Neutralize `PT_INTERP`** in `stage2/relocate`: patchelf
      `--set-interpreter /lib/<ld-musl>` on each `.real` (+ existing rpath removal);
      patchelf now required (fail-fast).
- [x] **`--argv0` in the trampoline** (unplanned, REQUIRED): neutralizing interp
      surfaced a LATENT LTO-portability bug — `lto-wrapper` re-spawns `COLLECT_GCC`
      DIRECTLY (kernel reads `gcc.real`'s interp). The old stage1-abs interp only
      existed on the build box, so distributed LTO was already broken. Fix: musl
      loader `--argv0 "$me"` makes GCC self-spawns route back through the trampoline
      (loader supplied explicitly) — never kernel-execs a `.real`. LTO now portable.

**Results (x86_64-stage2, install-only 14s):** `dist/x86_64-linux-musl` = **638 MB**
(gcc.real 20.7→**2.5 MB**); interp = `/lib/ld-musl-x86_64.so.1`, **zero `$HOME`
leaks** across all `.real`; **run-tests 12/12**, **run-caps 14 pass / 1 skip (cet)**;
**moved-tree LTO `-static` compiles + runs** (portability proven).

## Slice 2 — relocation modes

- [ ] `relocate --native` (patchelf abs interp on real ELF, no wrappers) —
      idempotent; the mise/clean path.
- [ ] Compiled **static-musl launcher** replacing the `/bin/sh` trampoline for
      portable mode (fixes `file gcc`=script + per-compile shell-fork storm).
      MUST replicate the loader-exec + `--argv0=self` semantics (Slice 1 LTO fix)
      or LTO re-spawns break again.
- [ ] `relocate --native` note: patchelf sets the REAL abs interp, so direct
      `.real` execs work without the trampoline — LTO is fine in native mode by
      construction; the `--argv0` concern is portable-mode-only.
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
