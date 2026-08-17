
OUTPUT = $(CURDIR)/output

BINUTILS_SRCDIR = BINUTILS_SRCDIR_not_set
GCC_SRCDIR = GCC_SRCDIR_not_set
MUSL_SRCDIR = MUSL_SRCDIR_not_set

GCC_CONFIG_FOR_TARGET = 
COMMON_CONFIG = 
GCC_CONFIG = 
TOOLCHAIN_CONFIG = 

XGCC_DIR = ../obj_gcc/gcc
XGCC = $(XGCC_DIR)/xgcc -B $(XGCC_DIR)

-include config.mak

ifneq ($(findstring fdpic,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --enable-fdpic
endif

ifneq ($(filter x86_64%x32,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --with-abi=x32
endif

ifneq ($(findstring powerpc64,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --with-abi=elfv2
endif

ifneq ($(findstring mips64,$(TARGET))$(findstring mipsisa64,$(TARGET)),)
ifneq ($(findstring n32,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --with-abi=n32
else
GCC_CONFIG_FOR_TARGET += --with-abi=64
endif
endif

ifneq ($(findstring s390x,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --with-long-double-128
endif

ifneq ($(filter %sf,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --with-float=soft
endif

ifneq ($(filter %hf,$(TARGET)),)
GCC_CONFIG_FOR_TARGET += --with-float=hard
endif

ifneq ($(LIBTOOL),)
LIBTOOL_ARG = LIBTOOL=$(LIBTOOL)
endif

MAKE += MULTILIB_OSDIRNAMES=
MAKE += INFO_DEPS= infodir=
MAKE += ac_cv_prog_lex_root=lex.yy
MAKE += MAKEINFO=false

FULL_BINUTILS_CONFIG = \
	--disable-separate-code \
	$(COMMON_CONFIG) $(BINUTILS_CONFIG) $(TOOLCHAIN_CONFIG) \
	--disable-werror \
	--target=$(TARGET) --prefix= \
	--libdir=/lib --disable-multilib \
	--with-sysroot=$(SYSROOT) \
	--enable-deterministic-archives

# libsanitizer is no longer hardcoded off here — it is preset-controlled via
# $(GCC_CONFIG) (presets/base disables it; presets/x86_64 re-enables it, since
# gcc's libsanitizer only builds cleanly on musl for x86_64 — Alpine parity).
FULL_GCC_CONFIG = --enable-languages=c,c++ \
	$(GCC_CONFIG_FOR_TARGET) \
	$(COMMON_CONFIG) $(GCC_CONFIG) $(TOOLCHAIN_CONFIG) \
	--disable-bootstrap \
	--disable-assembly \
	--disable-werror \
	--target=$(TARGET) --prefix= \
	--libdir=/lib --disable-multilib \
	--with-sysroot=$(SYSROOT) \
	--enable-tls \
	--disable-libmudflap \
	--disable-gnu-indirect-function \
	--disable-libmpx \
	--enable-initfini-array \
	--enable-libstdcxx-time=rt

FULL_MUSL_CONFIG = $(MUSL_CONFIG) \
	--prefix= --host=$(TARGET)

ifneq ($(NATIVE),)
HOST:=$(TARGET)
endif

ifeq ($(BUILD),)
GUESS = $(shell cd $(GCC_SRCDIR) && ./config.guess)
TARGET_CANON = $(shell cd $(GCC_SRCDIR) && ./config.sub $(TARGET))
BUILD = $(GUESS)$(if $(subst $(TARGET_CANON),,$(GUESS)),,xx)
endif

ifeq ($(HOST),)
SYSROOT = /$(TARGET)
FULL_BINUTILS_CONFIG += --build=$(BUILD) --host=$(BUILD)
FULL_GCC_CONFIG += --with-build-sysroot=$(CURDIR)/obj_sysroot \
	AR_FOR_TARGET=$(PWD)/obj_binutils/binutils/ar \
	AS_FOR_TARGET=$(PWD)/obj_binutils/gas/as-new \
	LD_FOR_TARGET=$(PWD)/obj_binutils/ld/ld-new \
	NM_FOR_TARGET=$(PWD)/obj_binutils/binutils/nm-new \
	OBJCOPY_FOR_TARGET=$(PWD)/obj_binutils/binutils/objcopy \
	OBJDUMP_FOR_TARGET=$(PWD)/obj_binutils/binutils/objdump \
	RANLIB_FOR_TARGET=$(PWD)/obj_binutils/binutils/ranlib \
	READELF_FOR_TARGET=$(PWD)/obj_binutils/binutils/readelf \
	STRIP_FOR_TARGET=$(PWD)/obj_binutils/binutils/strip-new \
	--build=$(BUILD) --host=$(BUILD) \
	# end
FULL_MUSL_CONFIG += CC="$(XGCC)" LIBCC="../obj_gcc/$(TARGET)/libgcc/libgcc.a" 
MUSL_VARS = AR=../obj_binutils/binutils/ar RANLIB=../obj_binutils/binutils/ranlib
obj_musl/.lc_configured: | obj_gcc/gcc/.lc_built
obj_musl/.lc_built: | obj_gcc/$(TARGET)/libgcc/libgcc.a
obj_gcc/gcc/.lc_built: | obj_sysroot/usr obj_sysroot/lib32 obj_sysroot/lib64 obj_sysroot/include
obj_gcc/.lc_built: | obj_sysroot/.lc_libs obj_sysroot/.lc_headers
obj_gcc/.lc_configured: obj_binutils/.lc_built
# Regenerate gcc's internal headers once musl's exist, before any target lib is
# built against a standalone <limits.h> (see the obj_gcc/gcc/.lc_limits rule).
obj_gcc/$(TARGET)/libgcc/libgcc.a: | obj_gcc/gcc/.lc_limits
obj_gcc/.lc_built: | obj_gcc/gcc/.lc_limits
else
SYSROOT = /
FULL_BINUTILS_CONFIG += --build=$(BUILD) --host=$(HOST)
FULL_GCC_CONFIG += --build=$(BUILD) --host=$(HOST)
MUSL_VARS = 
endif

ifeq ($(TARGET),)

all:
	@echo TARGET must be set.
	@exit 1

install: all

else

all: musl gcc binutils

install: install-musl install-gcc install-binutils

musl: obj_musl/.lc_built

toolchain: gcc binutils

install-toolchain: install-gcc install-binutils

gcc: obj_gcc/.lc_built

binutils: obj_binutils/.lc_built

.PHONY: all musl toolchain install-musl install-toolchain clean

src_binutils: | $(BINUTILS_SRCDIR)
	ln -sf $(BINUTILS_SRCDIR) $@

src_gcc_base: | $(GCC_SRCDIR)
	ln -sf $(GCC_SRCDIR) $@

src_musl: | $(MUSL_SRCDIR)
	ln -sf $(MUSL_SRCDIR) $@

ifneq ($(GMP_SRCDIR),)
src_gcc: src_gmp
src_gmp: | $(GMP_SRCDIR)
	ln -sf "$(GMP_SRCDIR)" $@
endif

ifneq ($(MPC_SRCDIR),)
src_gcc: src_mpc
src_mpc: | $(MPC_SRCDIR)
	ln -sf "$(MPC_SRCDIR)" $@
endif

ifneq ($(MPFR_SRCDIR),)
src_gcc: src_mpfr
src_mpfr: | $(MPFR_SRCDIR)
	ln -sf "$(MPFR_SRCDIR)" $@
endif

ifneq ($(ISL_SRCDIR),)
src_gcc: src_isl
src_isl: | $(ISL_SRCDIR)
	ln -sf "$(ISL_SRCDIR)" $@
endif

# zstd is not an in-tree gcc subdir (unlike gmp/mpfr/mpc/isl). Build a static
# libzstd.a into obj_zstd/dest so gcc and binutils compress debug sections with
# our archive instead of NEEDED-ing the host's shared libzstd.so.
ifneq ($(ZSTD_SRCDIR),)
src_zstd: | $(ZSTD_SRCDIR)
	ln -sf "$(ZSTD_SRCDIR)" $@
ZSTD_DEST = $(CURDIR)/obj_zstd/dest
# Compiler for the in-tree lib must match the one gcc/binutils host tools use,
# so the archive's objects share their libc. stage1 uses the host cc; stage2
# sets ZSTD_CC to its musl host-cc wrapper (presets/x86_64-stage2). If you
# override the host CC via COMMON_CONFIG, set ZSTD_CC to match (or blank
# ZSTD_VER to fall back to the system libzstd).
zstd_cc = $(or $(ZSTD_CC),$(CC),cc)
# gcc honours --with-zstd=DIR directly. binutils' AC_ZSTD is pkg-config only
# and ignores the DIR, so we hand it a generated .pc via PKG_CONFIG_PATH and
# pass --with-zstd=yes so a missing/broken .pc is a hard configure error, not a
# silent no-zstd build. --disable-shared: with only a static libzstd.a on
# offer, keep libbfd/libopcodes static too (this fork builds cross tools, not a
# shared libbfd for gdb) — sidesteps embedding a .a into a .so. ZSTD_LIBS from
# the .pc already reaches every tool's link line, so no manual LIBS= is needed.
FULL_BINUTILS_CONFIG += --with-zstd=yes --disable-shared
FULL_GCC_CONFIG += --with-zstd=$(ZSTD_DEST)

# What gcc records as "Configured with:" — via TOPLEVEL_CONFIGURE_ARGUMENTS it
# becomes configargs.h and a string inside EVERY frontend binary (`gcc -v`).
# The real args carry build-box absolute paths (CC= wrappers, *_FOR_TARGET,
# --with-build-sysroot, --with-zstd, --with-debug-prefix-map), so distributed
# trees would leak local paths. Record the same args with the build-dir and
# repo-root prefixes stripped instead. Display-only: the actual configure
# invocation above is untouched. Empty when MCM_ROOT is unset (plain builds).
ifneq ($(MCM_ROOT),)
CONFIGARGS_CLEAN = ../src_gcc/configure $(subst $(MCM_ROOT),,$(subst $(MCM_ROOT)/,,$(subst $(CURDIR),,$(subst $(CURDIR)/,,$(FULL_GCC_CONFIG)))))
GCC_TCA = 'TOPLEVEL_CONFIGURE_ARGUMENTS=$(CONFIGARGS_CLEAN)'
endif

obj_binutils/.lc_configured: | obj_zstd/.lc_built
obj_gcc/.lc_configured: | obj_zstd/.lc_built
obj_zstd/.lc_built: | src_zstd obj_zstd
	$(MAKE) -C src_zstd/lib libzstd.a CC="$(zstd_cc)" MOREFLAGS="-fPIC -O2 -g0"
	mkdir -p $(ZSTD_DEST)/include $(ZSTD_DEST)/lib/pkgconfig
	cp -f src_zstd/lib/zstd.h src_zstd/lib/zstd_errors.h src_zstd/lib/zdict.h $(ZSTD_DEST)/include/
	cp -f src_zstd/lib/libzstd.a $(ZSTD_DEST)/lib/
	sed -e 's|@PREFIX@|$(ZSTD_DEST)|' -e 's|@VERSION@|$(or $(ZSTD_VER),1.5.7)|' \
	  $(MCM_ROOT)/litecross/libzstd.pc.in > $(ZSTD_DEST)/lib/pkgconfig/libzstd.pc
	test -f $(ZSTD_DEST)/lib/libzstd.a && ! test -e $(ZSTD_DEST)/lib/libzstd.so
	touch $@
# Prefer our .pc over the host's so binutils does not NEEDED libzstd.so.1.
export PKG_CONFIG_PATH := $(ZSTD_DEST)/lib/pkgconfig$(if $(PKG_CONFIG_PATH),:$(PKG_CONFIG_PATH))
endif

# libxml2 is a *target* library (COBOL XML PARSE): libgcobol compiles and
# links against it, and static user links resolve -lxml2 from the shipped
# sysroot. Build it with the mid-build xgcc once musl is installed in
# obj_sysroot, before gcc's target libs configure (obj_gcc/.lc_built).
ifneq ($(LIBXML2_SRCDIR),)
src_libxml2: | $(LIBXML2_SRCDIR)
	ln -sf "$(LIBXML2_SRCDIR)" $@

# Feature set is exactly what libgcobol's xmlparse.cc needs: core SAX2 parser
# + push (xmlCreatePushParserCtxt/xmlParseChunk) + sax1 (xmlSAXUserParseMemory)
# + iconv (musl's built-in; EBCDIC pages via patches/musl-*/iconv-ebcdic-
# codepages.diff) + threads. --with-pic so the static archive's PIC objects
# can fold into libgcobol.so. Everything else (HTML, XPath, output/writer,
# reader, schemas, catalogs, zlib) stays off: smaller lib, smaller CVE surface.
LIBXML2_CONFIG = --build=$(BUILD) --host=$(TARGET) --prefix= \
	--disable-shared --enable-static --with-pic \
	--with-minimum --with-push --with-sax1 --with-iconv --with-threads

# CC: xgcc + gcc dir (as/ld shims) + libgcc build dir (libgcc.a, crt*.o) +
# build sysroot (musl headers/libs). At this point only the bootstrap
# enable_shared=no libgcc exists: no libgcc_s.so, no libgcc_eh.a (its objects
# are folded into libgcc.a), and none of gcc 16's *_asneeded linker scripts
# (installed later by the full libgcc/libatomic builds) — yet gcc 16's link
# specs inject -latomic_asneeded always and -lgcc_s_asneeded on dynamic
# links.  So: -fno-link-libatomic drops the former, -static-libgcc avoids
# the latter, and an empty libgcc_eh.a stub (private -B dir, correct here
# because eh lives inside the bootstrap libgcc.a) satisfies -static-libgcc's
# -lgcc_eh.  Only configure's conftest links ever use these; the libxml2
# build itself just compiles and archives.
LIBXML2_CC = $(CURDIR)/obj_gcc/gcc/xgcc -B $(CURDIR)/obj_gcc/gcc \
	-B $(CURDIR)/obj_gcc/$(TARGET)/libgcc -B $(CURDIR)/obj_libxml2/stubs \
	--sysroot=$(CURDIR)/obj_sysroot -static-libgcc -fno-link-libatomic

obj_libxml2/.lc_configured: | obj_libxml2 src_libxml2 obj_sysroot/.lc_libs
	mkdir -p obj_libxml2/stubs
	obj_binutils/binutils/ar rcs obj_libxml2/stubs/libgcc_eh.a
	cd obj_libxml2 && ../src_libxml2/configure $(LIBXML2_CONFIG) \
		CC="$(LIBXML2_CC)" CFLAGS="-O2 -g0" \
		AR=$(CURDIR)/obj_binutils/binutils/ar \
		RANLIB=$(CURDIR)/obj_binutils/binutils/ranlib \
		NM=$(CURDIR)/obj_binutils/binutils/nm-new
	touch $@

# Install by hand (zstd pattern): headers + libxml2.a only — no .la/.pc/cmake/
# xml2-config, nothing that could embed build paths or confuse later libtool
# links. xmlversion.h is the one generated header; listed after the srcdir
# glob so it overwrites any pre-generated copy shipped in the tarball.
obj_libxml2/.lc_built: | obj_libxml2/.lc_configured
	cd obj_libxml2 && $(MAKE) libxml2.la
	mkdir -p obj_sysroot/include/libxml2/libxml obj_sysroot/lib
	cp -f src_libxml2/include/libxml/*.h obj_libxml2/include/libxml/xmlversion.h \
		obj_sysroot/include/libxml2/libxml/
	cp -f obj_libxml2/.libs/libxml2.a obj_sysroot/lib/
	touch $@

obj_gcc/.lc_built: | obj_libxml2/.lc_built

# libgcobol: upstream --with-target-libxml2 split form. The -include form is
# used verbatim (no /libxml2 appended), so point it at the real header root.
# Plain paths match the default multilib (mldir "."), the only one here
# (--disable-multilib). Patch 0015 keeps -L<builddir> out of the installed
# libgcobol.la/spec (raw-path leak) — the build sysroot is already searched.
FULL_GCC_CONFIG += \
	--with-target-libxml2-include=$(CURDIR)/obj_sysroot/include/libxml2 \
	--with-target-libxml2-lib=$(CURDIR)/obj_sysroot/lib

install-libxml2: | obj_libxml2/.lc_built
	mkdir -p $(DESTDIR)$(OUTPUT)$(SYSROOT)/include/libxml2/libxml \
		$(DESTDIR)$(OUTPUT)$(SYSROOT)/lib
	cp -f src_libxml2/include/libxml/*.h obj_libxml2/include/libxml/xmlversion.h \
		$(DESTDIR)$(OUTPUT)$(SYSROOT)/include/libxml2/libxml/
	cp -f obj_libxml2/.libs/libxml2.a $(DESTDIR)$(OUTPUT)$(SYSROOT)/lib/

install: install-libxml2
endif

src_gcc: src_gcc_base
	rm -rf $@ $@.tmp
	mkdir $@.tmp
	cd $@.tmp && ln -sf ../src_gcc_base/* .
	$(if $(GMP_SRCDIR),cd $@.tmp && ln -sf ../src_gmp gmp)
	$(if $(MPC_SRCDIR),cd $@.tmp && ln -sf ../src_mpc mpc)
	$(if $(MPFR_SRCDIR),cd $@.tmp && ln -sf ../src_mpfr mpfr)
	$(if $(ISL_SRCDIR),cd $@.tmp && ln -sf ../src_isl isl)
	mv $@.tmp $@

obj_%:
	mkdir -p $@

obj_sysroot/include:
	mkdir -p $@

obj_sysroot/usr: | obj_sysroot
	ln -sf . $@

obj_sysroot/lib32: | obj_sysroot
	ln -sf lib $@

obj_sysroot/lib64: | obj_sysroot
	ln -sf lib $@

obj_binutils/.lc_configured: | obj_binutils src_binutils
	cd obj_binutils && ../src_binutils/configure $(FULL_BINUTILS_CONFIG)
	touch $@

obj_binutils/.lc_built: | obj_binutils/.lc_configured
	cd obj_binutils && $(MAKE) MAKE="$(MAKE) $(LIBTOOL_ARG)" all
	touch $@

obj_gcc/.lc_configured: | obj_gcc src_gcc
	cd obj_gcc && ../src_gcc/configure $(FULL_GCC_CONFIG)
	touch $@

obj_gcc/gcc/.lc_built: | obj_gcc/.lc_configured
	cd obj_gcc && $(MAKE) $(GCC_TCA) MAKE="$(MAKE) $(LIBTOOL_ARG)" all-gcc
	touch $@

obj_musl/.lc_configured: | obj_musl src_musl
	cd obj_musl && ../src_musl/configure $(FULL_MUSL_CONFIG)
	touch $@

obj_sysroot/.lc_headers: | obj_musl/.lc_configured obj_sysroot $(if $(LINUX_ARCH),obj_kernel_headers/.lc_built)
	cd obj_musl && $(MAKE) DESTDIR=$(CURDIR)/obj_sysroot install-headers
	@# The build sysroot needs the kernel uapi headers too, not just libc:
	@# libsanitizer includes <asm/param.h> etc. Other target libs don't, which
	@# is why obj_sysroot got away without them until libsanitizer was enabled.
	@# (install-kernel-headers still copies them into the final output sysroot.)
	$(if $(LINUX_ARCH),cp -R obj_kernel_headers/staged/include/* obj_sysroot/include/)
	touch $@

obj_gcc/$(TARGET)/libgcc/libgcc.a: | obj_sysroot/.lc_headers
	cd obj_gcc && $(MAKE) $(GCC_TCA) MAKE="$(MAKE) enable_shared=no $(LIBTOOL_ARG)" all-target-libgcc

# Cross gcc emits a *standalone* <limits.h> during all-gcc: the sysroot is empty,
# so LIMITS_H_TEST ([ -f build-sysroot/usr/include/limits.h ]) is false and gcc
# ships glimits.h alone (ISO limits only — no SSIZE_MAX/PATH_MAX, MB_LEN_MAX=1).
# Once musl headers exist, regenerate just the gcc internal headers so the test
# passes and gcc emits its official limitx+glimits+limity wrapper that
# #include_next's musl. stmp-fixinc is left in place (fixincludes must NOT rerun
# over libc headers); only stmp-int-hdrs is remade — cc1/xgcc are not rebuilt.
obj_gcc/gcc/.lc_limits: obj_gcc/gcc/.lc_built obj_sysroot/.lc_headers
	rm -f obj_gcc/gcc/stmp-int-hdrs
	cd obj_gcc && $(MAKE) $(GCC_TCA) MAKE="$(MAKE) $(LIBTOOL_ARG)" -C gcc stmp-int-hdrs
	grep -q _GCC_LIMITS_H_ obj_gcc/gcc/include/limits.h || { echo "lc_limits: limits.h still standalone (LIMITS_H_TEST false) -- refusing to ship" >&2; exit 1; }
	touch $@

obj_musl/.lc_built: | obj_musl/.lc_configured
	cd obj_musl && $(MAKE) $(MUSL_VARS)
	touch $@

obj_sysroot/.lc_libs: | obj_musl/.lc_built
	cd obj_musl && $(MAKE) $(MUSL_VARS) DESTDIR=$(CURDIR)/obj_sysroot install
	touch $@

obj_gcc/.lc_built: | obj_gcc/.lc_configured obj_gcc/gcc/.lc_built
	cd obj_gcc && $(MAKE) $(GCC_TCA) MAKE="$(MAKE) $(LIBTOOL_ARG)"
	touch $@

install-musl: | obj_musl/.lc_built
	cd obj_musl && $(MAKE) $(MUSL_VARS) DESTDIR=$(DESTDIR)$(OUTPUT)$(SYSROOT) install
	@# musl links ld-musl-<arch>.so.1 to the ABSOLUTE $(libdir)/libc.so, which
	@# escapes the sysroot: dangles wherever the tree is extracted, and under
	@# qemu-user -L resolves to the HOST /lib. libc.so is adjacent — go relative.
	for f in $(DESTDIR)$(OUTPUT)$(SYSROOT)/lib/ld-musl-*.so.1; do \
		! test -L $$f || ln -sf libc.so $$f; done

install-binutils: | obj_binutils/.lc_built
	cd obj_binutils && $(MAKE) MAKE="$(MAKE) $(LIBTOOL_ARG)" DESTDIR=$(DESTDIR)$(OUTPUT) install

install-gcc: | obj_gcc/.lc_built
	cd obj_gcc && $(MAKE) $(GCC_TCA) MAKE="$(MAKE) $(LIBTOOL_ARG)" DESTDIR=$(DESTDIR)$(OUTPUT) install
	ln -sf $(TARGET)-gcc $(DESTDIR)$(OUTPUT)/bin/$(TARGET)-cc

ifneq ($(LINUX_SRCDIR),)
TARGET_ARCH = $(firstword $(subst -, ,$(TARGET)))
TARGET_ARCH_MANGLED = $(patsubst or1k,openrisc,$(patsubst i%86,x86,$(patsubst aarch64%,arm64%,$(TARGET_ARCH))))
LINUX_ARCH_LIST = $(sort $(notdir $(wildcard $(LINUX_SRCDIR)/arch/*)))
LINUX_ARCH = $(lastword $(foreach a,$(LINUX_ARCH_LIST),$(if $(filter $(a)%,$(TARGET_ARCH_MANGLED)),$(a))))
ifneq ($(LINUX_ARCH),)
all: kernel-headers
install: install-kernel-headers
kernel-headers: | obj_kernel_headers/.lc_built
src_kernel_headers: | $(LINUX_SRCDIR)
	ln -sf "$(LINUX_SRCDIR)" $@
obj_kernel_headers/.lc_built: | src_kernel_headers
	mkdir -p $(CURDIR)/obj_kernel_headers/staged
	cd src_kernel_headers && $(MAKE) ARCH=$(LINUX_ARCH) O=$(CURDIR)/obj_kernel_headers INSTALL_HDR_PATH=$(CURDIR)/obj_kernel_headers/staged headers_install
	find obj_kernel_headers/staged/include '(' -name .install -o -name ..install.cmd ')' -exec rm {} +
	touch $@
install-kernel-headers: | obj_kernel_headers/.lc_built
	mkdir -p $(DESTDIR)$(OUTPUT)$(SYSROOT)/include
	cp -R obj_kernel_headers/staged/include/* $(DESTDIR)$(OUTPUT)$(SYSROOT)/include
endif
endif

endif

clean:
	rm -rf src_* obj_*
