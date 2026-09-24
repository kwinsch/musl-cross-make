# fortify-headers (vendored)

Standalone, libc-agnostic `_FORTIFY_SOURCE` implementation — bare musl ships no
fortify machinery, so `-D_FORTIFY_SOURCE=N` is a no-op without these headers.

- Upstream: https://github.com/jvoisin/fortify-headers
- Version:  3.0.2
- License:  0BSD (see LICENSE)
- Tarball sha256: a4aab14c56eb00239cbd61ac65b3e778cf29ec82f06116ba343a50552882f587
  (sha512 matches Alpine aports' published sum for fortify-headers-3.0.2.tar.gz)

Local modifications (the tree under `include/` is 3.0.2 PLUS these; each is
kept as a diff in `patches/` for upstreaming and re-application on update):

- `patches/0001-sprintf-vsprintf-bos0.diff` — sprintf/vsprintf sized by the
  maximum object size; fixes a level-2 false positive and an unchecked
  overflow at exactly 0 bytes remaining (2026-09-24, r5).

Vendored (header-only, ~10 files) rather than downloaded: keeps the build
offline/reproducible and avoids GitHub tag-tarball naming that doesn't fit the
top-level Makefile's download rules. To update: drop a new `include/` here,
re-apply `patches/*.diff` (drop the ones upstream merged), bump the version
+ hash, and re-verify against upstream.

Wired in by `patches/gcc-16.2.0/0014-add-fortify-headers-paths.diff` (adds
`<sysroot>/include/fortify` ahead of the musl headers) + the Makefile `install`
rule (copies these into `output/<triple>/include/fortify/`). Same mechanism
Alpine uses (their gcc patch 0017 + fortify-headers package).
