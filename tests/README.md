# Toolchain smoke tests

`../run-tests` compiles and runs one small program per language against a
produced toolchain and compares stdout to the sibling `.expect` file. It is a
**publish gate**: a non-zero exit means the toolchain is not fit to ship.

These are *smoke* tests (does each language compile, link, and run?), not a
conformance suite. They deliberately touch the runtime areas our patches
affect — e.g. `cpp/exceptions` exercises libstdc++ unwinding, `c/math` links
libm, COBOL/Fortran exercise their runtimes.

## What is checked

Two things, not one:

1. **Behaviour** — the program runs (natively or under `qemu-<arch>`) and
   prints the expected output.
2. **Linkage** — the produced ELF is what the mode *promises*, inspected with
   the toolchain's own `readelf`. A binary that runs on the build host but is
   secretly half-baked is **failed** here. For `static`/`static-pie` the audit
   requires:
   - **no `PT_INTERP`** — no dynamic loader is needed;
   - **no `NEEDED` entries** — no `libc.so`, `libstdc++.so`, `libgfortran.so`,
     `libgcobol.so`, and crucially **no `libgcc_s.so`** dragged in behind a
     `-static` flag;
   - **ELF type** matches the mode (`static` → `EXEC`, `static-pie` → `DYN`);
   - **ELF machine** matches the target arch (catches a wrong-toolchain mix-up).

   The audit runs even under `--compile-only`, so a foreign target with no
   qemu is still verified to be genuinely static and the right architecture.

## Modes

The default gate runs **both** `static` and `static-pie`.

| Mode | Flag | Link flags | Result |
|------|------|-----------|--------|
| `static` | `--static` | `-static -no-pie` | Classic fully static `ET_EXEC`. Movable file, no loader. |
| `static-pie` | `--pie` | `-static-pie -fPIE` | Static **and** position-independent (`ET_DYN`, ASLR, no loader). |
| `dynamic` | `--no-static` | *(none)* | Host/native sanity only; linkage audit relaxed. |

`--all-modes` is an explicit alias for the default (`static` + `static-pie`).

> **Default-PIE note.** Because `presets/base` sets `--enable-default-pie`, a
> bare `-static` on a toolchain built from these presets produces a static
> *PIE* (`ET_DYN`, still no interp / no NEEDED) — the same clean fully-static
> binary as `static-pie`. The `static` mode therefore adds `-no-pie` to also
> exercise the classic `ET_EXEC` path, so both outputs are guarded. (A bare
> flagless compile is a *dynamic* PIE that needs the musl loader — never
> portable; use `-static` or `-static-pie` for movable binaries.)

> **static-pie needs a PIE-capable toolchain.** Every target runtime library
> (`libc.a`, `libgcc`, `libstdc++`, `libgfortran`, `libgcobol`, …) must be built
> PIE-capable, or `-static-pie` fails at link time with `relocation R_X86_64_32…
> can not be used when making a PIE object`. `presets/base` sets
> `--enable-default-pie`, so a toolchain built from these presets is static-pie
> capable and the default gate passes both modes. If you point `--toolchain` at
> an **older** build made before that flag, the `static-pie` pass will fail with
> the remediation hint — rebuild it.

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

    ./run-tests                                  # both modes, against ./output after `make install`
    ./run-tests --static                         # plain static only
    ./run-tests --pie                            # static-PIE only
    ./run-tests --toolchain dist/aarch64-linux-musl
    ./run-tests --native                         # sanity-check the host compilers
    ./run-tests --list                           # show registry + discovered tests

Foreign targets run under `qemu-<arch>` (install qemu-user); if it is missing,
the run degrades to `--compile-only` for that arch with a warning — the ELF
linkage audit still runs. Because the toolchains emit **static** musl binaries,
qemu-user needs no sysroot.
