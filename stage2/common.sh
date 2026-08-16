# stage2/common.sh — shared helpers for the stage2 BUILD-BOX scripts.
# Sourced (not executed) by host-cc, host-c++, strip-host, and relocate (repo
# context only — the copy of relocate shipped inside a prefix never sources
# this). Callers set $root (repo checkout root) before sourcing.

# Resolve the bootstrap (stage1) toolchain that builds and runs the stage2
# host tools. Sets $stage1 and $stage1_triple; both overridable via env.
mcm_stage1_env() {
	stage1=${STAGE1:-"$root/output"}
	stage1_triple=${STAGE1_TRIPLE:-}
	if [ -z "$stage1_triple" ] && [ -f "$root/config.mak" ]; then
		stage1_triple=$(awk -F= '/^[[:space:]]*STAGE1_TRIPLE[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$root/config.mak" | tail -n1)
	fi
	[ -n "$stage1_triple" ] || { echo "$0: no STAGE1_TRIPLE (run ./configure <arch>-stage2)" >&2; exit 2; }
}

# /./-pad an absolute path to >= 512 bytes. Used as -Wl,-dynamic-linker so
# PT_INTERP reserves a fixed region the kernel still resolves (it normalizes
# the "." components) and stage2/setinterp can later rewrite in place —
# neutralize for packaging, or point at an install prefix — with no patchelf
# and no section surgery.
mcm_pad_interp() {
	_p=$1
	while [ ${#_p} -lt 512 ]; do _p="/.$_p"; done
	printf '%s' "$_p"
}
