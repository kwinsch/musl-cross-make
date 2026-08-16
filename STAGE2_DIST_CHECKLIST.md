# stage2 distribution — working checklist

> **TEMPORARY working doc — delete before merging `stage2-dist` to `master`.**
> Tracks turning the stage2 musl-hosted prefix into clean, distributable
> per-target packages. No absolute paths / hostnames / IPs in this file
> (it's committed to a public fork).

## Goal

One canonical stage2 build per target → **ONE `tar.zst` artifact**, serving the
public GitHub release, the mise `http`-backend index, and bare-Alpine
untar-and-run from the **same bytes**.

## Settled design (revised 2026-08-16 — supersedes the two-artifact model)

- **ONE artifact per target: the portable (launcher-wrapped) tree.**
  `musl-cross-<triple>-<version>.tar.zst`
  - GitHub human / Alpine box: untar → runs (launcher on glibc; on musl hosts
    even the `.real` files kernel-exec — the neutral interp is the real loader).
  - mise: `postinstall = relocate --native` promotes losslessly (drop launcher,
    rename `.real`, rewrite interp) → pristine ELF, identical end state to the
    old "canonical" artifact. Canonical is derivable ⇒ redundant ⇒ dropped.
  - Same backend both channels: mise `http:` against the GitHub release
    download URL (public) or the internal index base URL — only the base URL
    differs, artifact + checksum identical.
- **Consumer needs NOTHING but the tarball** — no patchelf: host tools are
  linked with a `/./`-padded `PT_INTERP` (fixed reserved size), so neutralize
  and native-promote are in-place string rewrites via a tiny bundled static
  tool. Fallback if the spike fails: bundle a static patchelf instead.
- **No rpath, ever**: host tools NEED only `libc.so` and the musl loader (== the
  interp == libc) satisfies that itself, so `-Wl,-rpath` is dropped at link
  time instead of scrubbed after. Build-box patchelf demoted to fallback.
- **`make install` keeps strip+wrap** (reverses the old Slice-4 plan):
  invariant "`dist/<triple>` is always shippable — no build-box paths, ever".
- **Version scheme:** `<gcc-version>-r<pkgrev>` (first release `16.2.0-r1`) —
  GitHub tag, mise version pin, and index path component.
- **Format:** deterministic `tar.zst` (sorted names, owner 0:0, clamped mtime)
  + `sha256` + `size` pinned inline in a committed `mise.toml` (reviewable).
- **Template:** mise URL uses `{{ version }}` (spaced/Tera) — NOT `{{version}}`
  (parses as legacy `{version}`, removed in mise 2027.3.0).
- **Host arch** = URL platform (linux-x64 today); **target triple** lives in the
  tool NAME, not the platforms table.

## mise POC — DONE ✅ (hermetic stand-in, 11/11) — with caveats

Proven on mise 2026.8.6: http backend from static URL · sha256+size enforced
(bad hash rejected) · strip_components · bin_path→PATH · per-tool `postinstall`
runs inside the extracted tree with `MISE_TOOL_INSTALL_PATH`.
**NOT yet proven (stand-in, not real bytes) — gates in Slice 3:**
hard-link preservation through mise's extraction (launcher sharing + `.real`
dedup, ~30 MB) · promote-from-wrapped as an actual postinstall.

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

## Slice 2 — relocation modes  ✅ DONE (x86_64-stage2 validated)

- [x] **Compiled static-musl launcher** (`stage2/launcher.c`, ~25 KB) replaces
      the `/bin/sh` trampoline. Static (no interp), self-locates via
      `/proc/self/exe`, execs `<self>.real` through the bundled loader with
      `--argv0 self` (keeps LTO re-spawns portable). `file gcc` → ELF, no
      per-compile shell fork. One binary, **hard-linked as all 50 wrappers**.
- [x] **`relocate --native [PREFIX]`**: patchelf `--set-interpreter` to the
      absolute prefix (`$MISE_TOOL_INSTALL_PATH` or OUTPUT); unwraps launcher +
      `.real`, leaves pristine ELF. Idempotent; move → re-run re-points.
- [x] **`.real` dedup**: byte-identical `.real` hard-linked to one inode
      (`ld.real`≡`ld.bfd.real`; `as.real` shared across both bin paths).
- [x] **KEY FINDING — never `patchelf --set-rpath` a long path here.** Native
      first segfaulted cc1: `--set-rpath` to a long abs path corrupts these
      binaries (short rpath / long *interp* are both fine). Root fix: native uses
      **`--set-interpreter` ONLY, no rpath** — the tools NEED just `libc.so`,
      which the musl loader (== the interp) satisfies, so no search path is
      needed. Bonus: interp-only makes move+re-point robust (no assertion abort).

**Results:** portable `dist/x86_64-linux-musl` = **605 MB** (was 638 MB pre-dedup),
`file gcc` = static ELF; run-tests 12/12 + run-caps 14/1skip in BOTH modes; moved
portable LTO OK; native move→re-point OK; native idempotent re-run OK.

## Slice 3 (revised) — one-artifact model proven end-to-end (x86_64)

Retire every remaining design risk with real bytes before building the
multi-target driver. Phases in order; each gates the next.

### 3.0 Spike — padded interp + in-place rewrite  ✅ GATE PASSED (7/7)

- [x] Padded interp: hello linked with `/./`-padded `-dynamic-linker` (513-byte
      `p_filesz`) execs normally; **no rpath and `libc.so` still resolves**
      (musl ldso == interp == libc satisfies its own NEEDED) — validates
      dropping `-Wl,-rpath` at link time.
- [x] `stage2/setinterp.c` (static, ~150 lines, strict ELF64/x86_64 checks):
      print + in-place rewrite. Verified: padded→neutral→abs rewrites, exec in
      each resolvable state, explicit-loader exec of neutral state, idempotent
      (byte-identical re-run), oversize path refused with exit 3, binary left
      intact on refusal.
- [x] **GATE PASSED → patchelf is OUT of the entire pipeline** (build box and
      consumer). No fallback needed.

### 3.1 Toolchain changes + rebuild

- [x] `stage2/common.sh`: `mcm_stage1_env` + `mcm_pad_interp` shared by
      host-cc/host-c++/strip-host/relocate (was 4 copies).
- [x] `host-cc`/`host-c++`: padded `-dynamic-linker` (≥512 B), **no `-rpath`**.
      Pre-flight smoke: both wrappers produce running binaries, interp reserved
      513 B, zero RPATH/RUNPATH.
- [x] `relocate` rewritten: context auto-detect (bundled loader beside script =
      shipped prefix). Shipped `--native` needs NOTHING but the tree itself —
      loader/dirs derived, interp via bundled setinterp, no readelf (ELF-probes
      via setinterp), no config.mak, no stage1, no patchelf. Build box: rpath
      is now **verify-none** (fail loudly). Also FIXED a latent re-install bug:
      `make install` over a wrapped tree overwrites launchers with fresh ELF
      but left stale `.real` → old early-return kept the tool unwrapped with a
      build-box interp; now detected (dynamic ELF + `.real` sibling) and
      re-wrapped. strip-host got the matching launcher-aware skip rule.
- [x] Ships activation in the tree: `<prefix>/relocate` +
      `<prefix>/libexec/mcm/setinterp`.
- [x] Full x86_64-stage2 rebuild #1 → `dist/x86_64-linux-musl` (609 MB,
      launcher 50-linked, relocate+setinterp shipped, interp neutral 513 B).
      **Regression gate PASSED:** run-tests 12/12 · run-caps 14 pass/1 skip —
      identical to Slice 1/2 baseline. no-rpath + padded-interp fully
      equivalent.
- [x] **GATE CATCH (new leak classes — the raw-string scan earned its keep;
      prior sessions only ever checked interp/rpath):**
      1. *Embedded configure line* (`gcc -v` "Configured with:") in every
         frontend binary via configargs.h — CC= wrapper paths, `*_FOR_TARGET`,
         `--with-build-sysroot`, `--with-zstd`, and `--with-debug-prefix-map`
         itself. FIX (no gcc patch): litecross now passes a sanitized
         `TOPLEVEL_CONFIGURE_ARGUMENTS` (build-dir + repo-root prefixes
         stripped) on every obj_gcc make — gcc/configure.ac takes it verbatim
         for configargs.h, so binaries are born clean. Display-only.
      2. *Unstripped host .so's outside the walked dirs*: `lib/libcc1.so*` +
         `lib/gcc/*/*/plugin/*.so*` carried build paths in debug info —
         strip-host now covers them.
      3. `install-tools/` (mkheaders.conf hardcodes the build sysroot; the
         tools are useless post-install) — strip-host now removes it.
      Sysroot itself was CLEAN — `--with-debug-prefix-map` works as intended.
- [x] Full rebuild #2 with sanitized configargs — reinstalled over the wrapped
      tree (live-tested the re-wrap fix: all launchers re-linked to one inode).
      Regression gate passed; compliance gate then surfaced the libcc1 class
      (see 3.2), fixed via `--disable-libcc1`.
- [x] Full rebuild #3 from scratch with all fixes: libcc1 never built,
      603 MB tree, run-tests 12/12, run-caps 14/1skip, **compliance gate
      passed first try**. Final artifact:
      `musl-cross-x86_64-linux-musl-16.2.0-r1.tar.zst` (168 MB,
      sha256 7d27a058…), mise round-trip re-verified (install 1.2 s, LTO OK).

### 3.2 Minimal packaging  ✅ DONE

- [x] `stage2/package OUTPUT VERSION` (target derived from tree basename):
      1. **Blocking compliance gate** — proven live: caught three real leak
         classes across two runs (embedded configure line, unstripped host
         .so debug info, libtool RPATH+dynamic-libstdc++ in libcc1). Checks:
         every host ELF interp exactly `/lib/<loader>` (probed via the
         bundled setinterp), zero RPATH/RUNPATH, zero raw repo-root strings
         tree-wide.
      2. Deterministic tar (sorted, owner 0:0, `SOURCE_DATE_EPOCH`-clamped,
         defaults to HEAD commit time) | zstd -T0 -19.
      **Result: 609 MB tree → 168 MB `tar.zst` in 26 s.** SHA256SUMS updated
      idempotently. (Signing + provenance manifest: publish slice.)
- [x] **libcc1 finding (3rd leak class):** libcc1.so + libcc1plugin/libcp1plugin
      NEED `libstdc++.so.6` dynamically (libtool drops `-static-libstdc++` on
      shared links) + hard RPATH into the stage1 tree — broken by construction
      in ANY shipped tree, gdb-`compile`-only feature. Fix at source:
      `GCC_CONFIG += --disable-libcc1` in presets/stage2.

### 3.3 Real consumer tests  ✅ ALL PASSED

- [x] **Human path**: untar (hard links preserved, launcher 49-linked) →
      `-static` + LTO compile+run on extract, zero steps → `./relocate
      --native` promotes with NO external tools → pristine (0 `.real`, real
      dynamic ELF, abs interp) → static+LTO again → idempotent re-run → move
      tree → re-point → works.
- [x] **mise path** (mise 2026.8.6, fresh `MISE_DATA_DIR`, localhost http,
      real 168 MB tarball): install **2.0 s** end-to-end — sha256+size
      verified, extracted, postinstall
      (`sh "$MISE_TOOL_INSTALL_PATH/relocate" --native`) promoted to native.
      **Hard links PRESERVED through mise extraction** (as shared across both
      bin paths, ld≡ld.bfd — the one-vs-two-artifact question is now closed:
      ONE artifact, no bloat). C, C++, LTO compile+run via mise-managed PATH.
- [x] **Alpine 3.21.7** (production version, podman, --network none): `.real`
      kernel-execs directly via the SYSTEM musl loader (neutral interp is the
      real loader there — zero-step property confirmed), launcher works,
      static + LTO compile+run.

### 3.4 Record  ✅ DONE

- [x] Results recorded throughout; POC caveats retired (hard-link preservation
      and promote-from-wrapped both proven with real bytes). **Slice 3 is
      complete: the one-artifact model is validated end-to-end on x86_64.**
      Next: Slice 4 (build-all over aarch64/armhf/riscv64 + package each).

## Slice 4 — build-all driver (revised)

- [x] `stage2/build-all VERSION [PRESET...]`: configure → **from-scratch**
      build → install (strip+wrap) → run-tests + run-caps → `stage2/package`
      per `*-stage2` preset; fail-fast; config.mak saved/restored. (strip+wrap
      STAYS in `make install` — the old "lift relocate out of install" item is
      dropped.)
- [x] **Gate catch #4 (first driver run):** an incremental build over the
      previous session's stale `build/stage2/aarch64-linux-musl` shipped a
      pre-padding gcobol with the old stage1 RPATH — relocate's verify-none
      check aborted the install. Driver now wipes BUILD_DIR + dist/<triple>
      per target: release builds are always from scratch.
- [x] aarch64 + armhf + riscv64 build-all run: **all three built, gated,
      packaged in ~35 min** (from-scratch each). run-tests 12/12 (armhf 10/2 —
      COBOL off there by design), run-caps 13/2skip, compliance gate passed
      per target, compile+audit mode (no qemu-user on this box; installing
      `qemu-user-static` upgrades to full run-gating automatically).
      Consumer spot-check on aarch64: portable-on-extract, LTO, native
      promote — all produce correct ARM aarch64 ELF.
      **Full 16.2.0-r1 set in dist/ + SHA256SUMS:** x86_64 168 MB (7d27a058…)
      · aarch64 134 MB (fb2fe160…) · armhf 104 MB (dc6c8dff…) · riscv64
      185 MB (1ebcd705…). **Slice 4 complete.**

## Slice 5 — publish + docs

- [ ] Publish: GitHub release + internal index, same bytes; sign `SHA256SUMS`
      (minisign/GPG) + provenance manifest (source versions, patch list,
      flattened config.mak).
- [ ] Emit mise.toml snippet: `{{ version }}`, inline checksum+size,
      `postinstall`, base-URL parameterized (public GitHub URL vs internal
      index var). Validate the env-indirection form mise supports in `url`.
- [ ] devstack `TOOL_DISTRIBUTION.md`: `{{ version }}` fix, one-artifact model,
      postinstall relocate, **pin minimum mise version (≥ 2026.8.x)**, doctor
      hook.
- [ ] Document the Alpine property (neutral interp = real loader there;
      zero-step on musl hosts).

## Merge hygiene (before `stage2-dist` → `master`)

- [x] README: stage2 section corrected (`dist/<target>`, launcher wording) +
      new distribution paragraph (package/build-all, run-on-extract, Alpine
      kernel-exec property, `./relocate --native`, mise postinstall).
- [x] `output-stage2/` removed (13 GB reclaimed).
- [x] `launcher.c` walk-up comment (target-sysroot loader on x86_64-stage2).
- [x] `SENSITIVE.md` created: tree rules + artifact rules (interp/rpath/raw
      strings, known past offenders) + gate usage + manual spot checks.
- [ ] Delete this file.
- [ ] Push master + branch (origin is 9 commits behind — whole stage2 series is
      on one machine, violating the off-machine-remote rule).

---

## Decisions / notes

- musl-dynamic host tools (NOT static): static musl can't `dlopen` →
  no `liblto_plugin.so` → no LTO/gcc-ar. Non-negotiable.
- `/proc/self/exe` is wrong under ANY wrapper (trampoline or launcher) — inherent;
  it's why `--native` (real ELF exec'd directly) is the clean default.
- Strip scope excludes target libs so users can still debug their own static
  binaries built against this toolchain.
- One-artifact + padded-interp decisions reviewed/ratified 2026-08-16 (session
  review); two-artifact model and consumer patchelf dependency dropped.
