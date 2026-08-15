# Toolchain smoke tests

`../run-tests` compiles and runs one small program per language against a
produced toolchain and compares stdout to the sibling `.expect` file. It is a
**publish gate**: a non-zero exit means the toolchain is not fit to ship.

These are *smoke* tests (does each language compile, link static, and run?),
not a conformance suite. They deliberately touch the runtime areas our patches
affect — e.g. `cpp/exceptions` exercises libstdc++ unwinding, `c/math` links
libm, COBOL/Fortran exercise their runtimes.

## Layout

    tests/<dir>/<name>.<ext>       source
    tests/<dir>/<name>.expect      expected stdout (trailing newline ignored)
    tests/<dir>/<name>.flags       optional: extra compile flags, one line (e.g. -lm)

## Extending

- **Add a test:** drop `<name>.<ext>` + `<name>.expect` into the language dir.
  Add `<name>.flags` if it needs extra flags.
- **Add a language:** add a row to `LANGREG` in `../run-tests`
  (`key|dir|driver|ext`) and create `tests/<dir>/`. A language whose driver is
  not in the toolchain is reported SKIP, never failed.

## Running

    ./run-tests                                  # against ./output after `make install`
    ./run-tests --toolchain dist/aarch64-linux-musl
    ./run-tests --native                         # sanity-check the host compilers
    ./run-tests --list                           # show registry + discovered tests

Foreign targets run under `qemu-<arch>` (install qemu-user); if it is missing,
the run degrades to `--compile-only` for that arch with a warning. Because the
toolchains emit **static** musl binaries, qemu-user needs no sysroot.

## Ada

`ada/hello.adb` is provided but Ada is off by default and builds via `gnatmake`
(a different invocation than the gcc-style drivers). Add an `ada` row to
`LANGREG` and a gnatmake path to the runner when Ada is enabled.
