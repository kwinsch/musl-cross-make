# SENSITIVE.md

What must never appear in this repository or in artifacts it produces.
This is a public repo; treat everything below as a hard rule.

## In the git tree

- No absolute build-box paths (home directories, checkout locations).
- No internal hostnames, IPs, ports, or index/registry URLs. Consumption
  configs that point at private infrastructure (package indexes, mise
  configs with internal URLs, tokens) live OUTSIDE this repo.
- `config.mak` is generated and local-only (gitignored) — never commit it.
- No credentials of any kind.

## In distributed artifacts (`dist/musl-cross-*.tar.zst`)

A shipped stage2 prefix must carry **zero build-box paths**:

- `PT_INTERP` of every host ELF must be exactly `/lib/ld-musl-<arch>.so.1`
  (portable/neutral form). Anything absolute into a checkout is a leak.
- No `DT_RPATH`/`DT_RUNPATH` anywhere (host tools need none — the musl
  loader IS libc and satisfies their single NEEDED entry itself).
- No raw path strings from the build machine anywhere in the tree —
  including embedded configure lines, debug info, and generated config
  files. Known past offenders: gcc's "Configured with:" string (now
  sanitized via `TOPLEVEL_CONFIGURE_ARGUMENTS` in `litecross/Makefile`),
  unstripped host `.so` debug info, libtool RPATHs (libcc1 — now
  `--disable-libcc1`), `install-tools/mkheaders.conf` (now removed by
  `stage2/strip-host`).
- No libtool `.la` files — their `libdir=`/`dependency_libs=` embed
  sysroot-absolute paths that misdirect libtool on consumer machines
  (deleted by `make install`, upstream mcm issue #166).
- No absolute symlinks — they dangle or escape into the host filesystem
  wherever the tree is extracted. `ld-musl-<arch>.so.1` is relinked
  relative to `libc.so` at install (upstream mcm issue #82).

## Compliance checks

`stage2/package` enforces all artifact rules as a **blocking gate** before
packing — run it (or just its gate) on any tree you intend to ship:

    stage2/package dist/<triple> <version>

Manual spot checks:

    # interp + rpath of every host ELF
    find dist/<triple>/bin dist/<triple>/libexec dist/<triple>/*/bin -type f \
      -exec sh -c 'readelf -ld "$1" 2>/dev/null | grep -E "interpreter|R(UN)?PATH" | grep "$HOME" && echo "LEAK: $1"' _ {} \;

    # raw byte scan for the checkout path
    grep -rl "$(pwd)" dist/<triple> && echo LEAK

When a new sensitive pattern is discovered: add it here AND teach the
`stage2/package` gate to catch it mechanically.
