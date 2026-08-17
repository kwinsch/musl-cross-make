#!/usr/bin/env python3
"""Differential verifier for the EBCDIC codepages bundled into musl
(patches/musl-*/iconv-ebcdic-codepages.diff).

Covers the complete z/OS XML System Services EBCDIC SBCS set, all 256 bytes,
both directions, against independent oracles:

  glibc iconv   -- primary source (fast, stable, everywhere)
  ICU uconv     -- IBM-lineage tables, closest to the IBM CDRA registry
  Python codecs -- only exist for 037/273/500/1140

Authority = glibc plus AUTHORITY_OVERRIDES.  The overrides exist because
glibc's legacy IBM278/IBM285/IBM871 tables are provably wrong: each euro page
(1141-1149) is defined by IBM as its base page with the currency sign replaced
by the euro at ONE position, and glibc's own euro variants contradict its base
tables at exactly the overridden bytes while agreeing with ICU.  That
"euro-sibling invariant" is enforced below for all ten pairs and is the
mechanical tie-breaker for table disputes.  (glibc bug-report candidate; see
TODO-upstream.md.)

gen_codepages.py imports the registry, authority and goldens from here, so
generator and verifier cannot drift apart.
"""
import codecs
import shutil
import subprocess
import sys

# The z/OS XML System Services EBCDIC SBCS set (stable since 2008; z/OS XML
# System Services User's Guide, SA38-0681, appendix "Supported encodings").
# ibm1047 is already in musl upstream: verified here, not regenerated.
# Alias lists are musl-style (lowercase alphanumerics; musl fuzzycmp ignores
# punctuation but *not* zeros, hence both ibm1141 and ibm01141 for the IANA
# IBM01141-style names of the euro pages).
#   (name, glibc, icu, python-codec-or-None, [aliases], in_tree)
PAGES = [
    ("IBM1047", "IBM1047", "ibm-1047", None,
     ["ibm1047", "cp1047"], True),
    ("IBM037",  "IBM037",  "ibm-37",   "cp037",
     ["ibm037", "cp037", "ebcdiccpus", "ebcdiccpca",
      "ebcdiccpwt", "ebcdiccpnl", "csibm037"], False),
    ("IBM273",  "IBM273",  "ibm-273",  "cp273",
     ["ibm273", "cp273", "csibm273"], False),
    ("IBM277",  "IBM277",  "ibm-277",  None,
     ["ibm277", "cp277", "ebcdiccpdk", "ebcdiccpno", "csibm277"], False),
    ("IBM278",  "IBM278",  "ibm-278",  None,
     ["ibm278", "cp278", "ebcdiccpfi", "ebcdiccpse", "csibm278"], False),
    ("IBM280",  "IBM280",  "ibm-280",  None,
     ["ibm280", "cp280", "ebcdiccpit", "csibm280"], False),
    ("IBM284",  "IBM284",  "ibm-284",  None,
     ["ibm284", "cp284", "ebcdiccpes", "csibm284"], False),
    ("IBM285",  "IBM285",  "ibm-285",  None,
     ["ibm285", "cp285", "ebcdiccpgb", "csibm285"], False),
    ("IBM297",  "IBM297",  "ibm-297",  None,
     ["ibm297", "cp297", "ebcdiccpfr", "csibm297"], False),
    ("IBM500",  "IBM500",  "ibm-500",  "cp500",
     ["ibm500", "cp500", "ebcdiccpbe", "ebcdiccpch", "csibm500"], False),
    ("IBM871",  "IBM871",  "ibm-871",  None,
     ["ibm871", "cp871", "ebcdiccpis", "csibm871"], False),
    ("IBM1140", "IBM1140", "ibm-1140", "cp1140",
     ["ibm1140", "cp1140", "ibm01140"], False),
    ("IBM1141", "IBM1141", "ibm-1141", None,
     ["ibm1141", "cp1141", "ibm01141"], False),
    ("IBM1142", "IBM1142", "ibm-1142", None,
     ["ibm1142", "cp1142", "ibm01142"], False),
    ("IBM1143", "IBM1143", "ibm-1143", None,
     ["ibm1143", "cp1143", "ibm01143"], False),
    ("IBM1144", "IBM1144", "ibm-1144", None,
     ["ibm1144", "cp1144", "ibm01144"], False),
    ("IBM1145", "IBM1145", "ibm-1145", None,
     ["ibm1145", "cp1145", "ibm01145"], False),
    ("IBM1146", "IBM1146", "ibm-1146", None,
     ["ibm1146", "cp1146", "ibm01146"], False),
    ("IBM1147", "IBM1147", "ibm-1147", None,
     ["ibm1147", "cp1147", "ibm01147"], False),
    ("IBM1148", "IBM1148", "ibm-1148", None,
     ["ibm1148", "cp1148", "ibm01148"], False),
    ("IBM1149", "IBM1149", "ibm-1149", None,
     ["ibm1149", "cp1149", "ibm01149"], False),
]

# base page -> euro page (IBM: identical except currency sign U+00A4 -> euro)
EURO_SIBLINGS = {
    "IBM037": "IBM1140", "IBM273": "IBM1141", "IBM277": "IBM1142",
    "IBM278": "IBM1143", "IBM280": "IBM1144", "IBM284": "IBM1145",
    "IBM285": "IBM1146", "IBM297": "IBM1147", "IBM500": "IBM1148",
    "IBM871": "IBM1149",
}

# Corrections applied on top of glibc, proven by the euro-sibling invariant
# (glibc's OWN 1143/1146/1149 tables agree with ICU here) and matching ICU:
AUTHORITY_OVERRIDES = {
    ("IBM278", 0x71): 0x005C,   # glibc says U+00C9; E-acute/backslash swapped
    ("IBM278", 0xE0): 0x00C9,   # glibc says U+005C
    ("IBM285", 0xA1): 0x00AF,   # glibc says U+203E; overline-vs-macron
    ("IBM871", 0x4A): 0x00DE,   # glibc says U+00FE; thorn case swapped
    ("IBM871", 0xC0): 0x00FE,   # glibc says U+00DE
}

# Tolerated third-oracle deviations from the authority (with rationale):
#   (page, byte): { oracle: codepoint }
DIVERGENCES = {
    # Python's cp273 maps 0xBC to U+203E OVERLINE; glibc and ICU agree on
    # U+00AF MACRON.  Same historic ambiguity as the IBM285 0xA1 override.
    ("IBM273", 0xBC): {"python": 0x203E},
}

ALLBYTES = bytes(range(256))


def glibc_map(name):
    out = subprocess.run(["iconv", "-f", name, "-t", "UTF-32LE"],
                         input=ALLBYTES, capture_output=True, check=True).stdout
    assert len(out) == 1024, f"glibc {name}: short decode"
    return [int.from_bytes(out[i:i + 4], "little") for i in range(0, 1024, 4)]


def icu_map(name):
    out = subprocess.run(["uconv", "-f", name, "-t", "UTF-32LE"],
                         input=ALLBYTES, capture_output=True, check=True).stdout
    cps = [int.from_bytes(out[i:i + 4], "little") for i in range(0, len(out), 4)]
    if cps and cps[0] == 0xFEFF:        # uconv may emit a BOM
        cps = cps[1:]
    assert len(cps) == 256, f"icu {name}: got {len(cps)} codepoints"
    return cps


def python_map(codec):
    return [ord(bytes([b]).decode(codec)) for b in range(256)]


def authority_map(page):
    name = page[0]
    m = glibc_map(page[1])
    for (pg, byte), cp in AUTHORITY_OVERRIDES.items():
        if pg == name:
            m[byte] = cp
    return m


def fnv64(data):
    h = 0xCBF29CE484222325
    for byte in data:
        h ^= byte
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return h


def golden(page):
    """FNV-1a 64 over the UTF-32LE dump of the authority decode of bytes
    0..255 -- the constant the run-caps ebcdic-iconv probe checks."""
    auth = authority_map(page)
    return fnv64(b"".join(c.to_bytes(4, "little") for c in auth))


def page_by_name(name):
    return next(p for p in PAGES if p[0] == name)


def check_page(page):
    name, glibc_name, icu_name, py_codec, _aliases, _in_tree = page
    auth = authority_map(page)
    ok = True

    # After overrides the authority must equal ICU everywhere.
    icu = icu_map(icu_name)
    for b in range(256):
        if icu[b] != auth[b]:
            print(f"FAIL {name} 0x{b:02X}: authority=U+{auth[b]:04X} "
                  f"icu=U+{icu[b]:04X}")
            ok = False

    # Python codecs, where they exist, modulo the documented divergences.
    if py_codec:
        pym = python_map(py_codec)
        for b in range(256):
            if pym[b] != auth[b] and \
               DIVERGENCES.get((name, b), {}).get("python") != pym[b]:
                print(f"FAIL {name} 0x{b:02X}: authority=U+{auth[b]:04X} "
                      f"python=U+{pym[b]:04X} (not in allowlist)")
                ok = False

    # Full permutation.
    assert len(set(auth)) == 256, f"{name}: not a bijection"

    # Encode direction: ICU (== authority) must roundtrip every byte.
    enc_in = "".join(chr(c) for c in auth).encode("utf-8")
    out = subprocess.run(["uconv", "-f", "UTF-8", "-t", icu_name],
                         input=enc_in, capture_output=True, check=True).stdout
    assert out == ALLBYTES, f"{name}: icu encode roundtrip mismatch"
    return ok


def check_euro_siblings():
    ok = True
    for base, euro in EURO_SIBLINGS.items():
        b = authority_map(page_by_name(base))
        e = authority_map(page_by_name(euro))
        d = [(i, b[i], e[i]) for i in range(256) if b[i] != e[i]]
        if len(d) != 1 or d[0][1] != 0x00A4 or d[0][2] != 0x20AC:
            print(f"FAIL euro-sibling {base}/{euro}: " +
                  " ".join(f"0x{i:02X}:U+{x:04X}->U+{y:04X}" for i, x, y in d))
            ok = False
    return ok


def main():
    assert shutil.which("iconv") and shutil.which("uconv"), \
        "need glibc iconv and ICU uconv on PATH"
    bad = 0
    for page in PAGES:
        if check_page(page):
            print(f"OK  {page[0]}: decode x oracles, bijection, encode "
                  f"roundtrip; golden=0x{golden(page):016x}")
        else:
            bad += 1
    if not check_euro_siblings():
        bad += 1
    else:
        print("OK  euro-sibling invariant holds for all 10 pairs")
    if bad:
        sys.exit(f"{bad} check(s) FAILED")
    print(f"all {len(PAGES)} pages verified")


if __name__ == "__main__":
    main()
