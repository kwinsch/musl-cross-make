
SOURCES = sources

CONFIG_SUB_REV = 3d5db9ebe860
BINUTILS_VER = 2.47
GCC_VER = 16.2.0
MUSL_VER = 1.2.6
GMP_VER = 6.3.0
MPC_VER = 1.3.1
MPFR_VER = 4.2.2
ISL_VER = 0.28
ZSTD_VER = 1.5.7
LINUX_VER = 6.18.44

GNU_SITE = https://ftpmirror.gnu.org/gnu
GCC_SITE = $(GNU_SITE)/gcc
BINUTILS_SITE = $(GNU_SITE)/binutils
GMP_SITE = $(GNU_SITE)/gmp
MPC_SITE = $(GNU_SITE)/mpc
MPFR_SITE = $(GNU_SITE)/mpfr
ISL_SITE = https://downloads.sourceforge.net/project/libisl/
ZSTD_SITE = https://github.com/facebook/zstd/releases/download/v$(ZSTD_VER)

MUSL_SITE = https://musl.libc.org/releases
MUSL_REPO = https://git.musl-libc.org/git/musl

LINUX_SITE = https://cdn.kernel.org/pub/linux/kernel
LINUX_HEADERS_SITE = https://ftp.barfooze.de/pub/sabotage/tarballs

DL_CMD = wget -c -O
HASH_CMD = sha256sum -c
SHA1_CMD = sha1sum -c

COWPATCH = $(CURDIR)/cowpatch.sh
# Repo root. Written into $(BUILD_DIR)/config.mak so stage2's CC= wrappers
# still resolve when litecross runs with a different CURDIR.
MCM_ROOT := $(abspath $(CURDIR))

HOST = $(if $(NATIVE),$(TARGET))
BUILD_DIR = build/$(if $(HOST),$(HOST),local)/$(TARGET)
OUTPUT = $(CURDIR)/output$(if $(HOST),-$(HOST))

REL_TOP = ../../..

-include config.mak

SRC_DIRS = gcc-$(GCC_VER) binutils-$(BINUTILS_VER) musl-$(MUSL_VER) \
	$(if $(GMP_VER),gmp-$(GMP_VER)) \
	$(if $(MPC_VER),mpc-$(MPC_VER)) \
	$(if $(MPFR_VER),mpfr-$(MPFR_VER)) \
	$(if $(ISL_VER),isl-$(ISL_VER)) \
	$(if $(ZSTD_VER),zstd-$(ZSTD_VER)) \
	$(if $(LINUX_VER),linux-$(LINUX_VER))

all:

# Cleanup tiers — each also loses what the cheaper tiers remove:
#   clean-build : build dirs only; extracted+patched source trees and the
#                 sources/ tarball cache stay (fast full rebuild, offline)
#   clean       : + extracted/patched source trees (tarballs stay; re-extract
#                 is minutes and needs no network)
#   distclean   : + the sources/ tarball cache (re-fetch needs network)
#   clean-dist  : orthogonal — stage2 dist/ trees, artifacts and SHA256SUMS;
#                 run before a release stage2/build-all so nothing stale
#                 (old-version artifacts, sums lines) survives into it
# No tier touches output/ — the installed stage1 is the stage2 bootstrap.
# NB: clean's globs match ANY gcc-*/musl-*/binutils-*/... entry at the repo
# root — don't park unrelated files or checkouts under such names (or under
# build/).
.PHONY: clean clean-build clean-dist distclean

clean-build:
	rm -rf build build-*

clean: clean-build
	rm -rf gcc-* binutils-* musl-* gmp-* mpc-* mpfr-* isl-* zstd-* linux-*

clean-dist:
	rm -rf dist

distclean: clean
	rm -rf sources


# Rules for downloading and verifying sources. Treat an external SOURCES path as
# immutable and do not try to download anything into it.

ifeq ($(SOURCES),sources)

$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/gmp*))): SITE = $(GMP_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/mpc*))): SITE = $(MPC_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/mpfr*))): SITE = $(MPFR_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/isl*))): SITE = $(ISL_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/zstd*))): SITE = $(ZSTD_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/binutils*))): SITE = $(BINUTILS_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/gcc*))): SITE = $(GCC_SITE)/$(basename $(basename $(notdir $@)))
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/musl*))): SITE = $(MUSL_SITE)
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/linux-6*))): SITE = $(LINUX_SITE)/v6.x
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/linux-5*))): SITE = $(LINUX_SITE)/v5.x
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/linux-4*))): SITE = $(LINUX_SITE)/v4.x
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/linux-3*))): SITE = $(LINUX_SITE)/v3.x
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/linux-2.6*))): SITE = $(LINUX_SITE)/v2.6
$(patsubst hashes/%.sha256,$(SOURCES)/%,$(patsubst hashes/%.sha1,$(SOURCES)/%,$(wildcard hashes/linux-headers-*))): SITE = $(LINUX_HEADERS_SITE)

$(SOURCES):
	mkdir -p $@

$(SOURCES)/config.sub: | $(SOURCES)
	mkdir -p $@.tmp
	cd $@.tmp && $(DL_CMD) $(notdir $@) "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=$(CONFIG_SUB_REV)"
	cd $@.tmp && touch $(notdir $@)
	cd $@.tmp && $(if $(wildcard $(CURDIR)/hashes/$(notdir $@).$(CONFIG_SUB_REV).sha256),$(HASH_CMD) $(CURDIR)/hashes/$(notdir $@).$(CONFIG_SUB_REV).sha256,$(SHA1_CMD) $(CURDIR)/hashes/$(notdir $@).$(CONFIG_SUB_REV).sha1)
	mv $@.tmp/$(notdir $@) $@
	rm -rf $@.tmp

# Hash files are order-only prereqs: they select which rule applies (sha256
# vs sha1) but must not make an EXISTING tarball look stale — a fresh checkout
# carries newer mtimes than a pre-seeded sources/ tree, and re-downloading
# already-verified tarballs breaks offline builds. An existing file is never
# re-fetched; rm it to force a re-download.
$(SOURCES)/%: | hashes/%.sha256 $(SOURCES)
	mkdir -p $@.tmp
	cd $@.tmp && $(DL_CMD) $(notdir $@) $(SITE)/$(notdir $@)
	cd $@.tmp && touch $(notdir $@)
	cd $@.tmp && $(HASH_CMD) $(CURDIR)/hashes/$(notdir $@).sha256
	mv $@.tmp/$(notdir $@) $@
	rm -rf $@.tmp

$(SOURCES)/%: | hashes/%.sha1 $(SOURCES)
	mkdir -p $@.tmp
	cd $@.tmp && $(DL_CMD) $(notdir $@) $(SITE)/$(notdir $@)
	cd $@.tmp && touch $(notdir $@)
	cd $@.tmp && $(SHA1_CMD) $(CURDIR)/hashes/$(notdir $@).sha1
	mv $@.tmp/$(notdir $@) $@
	rm -rf $@.tmp

endif


# Rules for extracting and patching sources, or checking them out from git.

musl-git-%:
	rm -rf $@.tmp
	git clone -b $(patsubst musl-git-%,%,$@) $(MUSL_REPO) $@.tmp
	cd $@.tmp && git fsck
	mv $@.tmp $@

%.orig: $(SOURCES)/%.tar.gz
	case "$@" in */*) exit 1 ;; esac
	rm -rf $@.tmp
	mkdir $@.tmp
	( cd $@.tmp && tar zxvf - ) < $<
	rm -rf $@
	touch $@.tmp/$(patsubst %.orig,%,$@)
	mv $@.tmp/$(patsubst %.orig,%,$@) $@
	rm -rf $@.tmp

%.orig: $(SOURCES)/%.tar.bz2
	case "$@" in */*) exit 1 ;; esac
	rm -rf $@.tmp
	mkdir $@.tmp
	( cd $@.tmp && tar jxvf - ) < $<
	rm -rf $@
	touch $@.tmp/$(patsubst %.orig,%,$@)
	mv $@.tmp/$(patsubst %.orig,%,$@) $@
	rm -rf $@.tmp

%.orig: $(SOURCES)/%.tar.xz
	case "$@" in */*) exit 1 ;; esac
	rm -rf $@.tmp
	mkdir $@.tmp
	( cd $@.tmp && tar Jxvf - ) < $<
	rm -rf $@
	touch $@.tmp/$(patsubst %.orig,%,$@)
	mv $@.tmp/$(patsubst %.orig,%,$@) $@
	rm -rf $@.tmp

%: %.orig
	case "$@" in */*) exit 1 ;; esac
	rm -rf $@.tmp
	mkdir $@.tmp
	( cd $@.tmp && $(COWPATCH) -I ../$< )
	test ! -d patches/$@ || cat patches/$@/* | ( cd $@.tmp && $(COWPATCH) -p1 )
	rm -rf $@
	mv $@.tmp $@


# Add deps for all patched source dirs on their patchsets
$(foreach dir,$(notdir $(basename $(basename $(basename $(wildcard hashes/*))))),$(eval $(dir): $$(wildcard patches/$(dir) patches/$(dir)/*)))

extract_all: | $(SRC_DIRS)


# Rules for building.

ifeq ($(TARGET),)

all:
	@echo TARGET must be set via config.mak or command line.
	@exit 1

else

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/Makefile: | $(BUILD_DIR)
	ln -sf $(REL_TOP)/litecross/Makefile $@

$(BUILD_DIR)/config.mak: | $(BUILD_DIR)
	printf >$@ '%s\n' \
	"TARGET = $(TARGET)" \
	"HOST = $(HOST)" \
	"MCM_ROOT = $(MCM_ROOT)" \
	"MUSL_SRCDIR = $(REL_TOP)/musl-$(MUSL_VER)" \
	"GCC_SRCDIR = $(REL_TOP)/gcc-$(GCC_VER)" \
	"BINUTILS_SRCDIR = $(REL_TOP)/binutils-$(BINUTILS_VER)" \
	$(if $(GMP_VER),"GMP_SRCDIR = $(REL_TOP)/gmp-$(GMP_VER)") \
	$(if $(MPC_VER),"MPC_SRCDIR = $(REL_TOP)/mpc-$(MPC_VER)") \
	$(if $(MPFR_VER),"MPFR_SRCDIR = $(REL_TOP)/mpfr-$(MPFR_VER)") \
	$(if $(ISL_VER),"ISL_SRCDIR = $(REL_TOP)/isl-$(ISL_VER)") \
	$(if $(ZSTD_VER),"ZSTD_SRCDIR = $(REL_TOP)/zstd-$(ZSTD_VER)") \
	$(if $(ZSTD_VER),"ZSTD_VER = $(ZSTD_VER)") \
	$(if $(LINUX_VER),"LINUX_SRCDIR = $(REL_TOP)/linux-$(LINUX_VER)") \
	"-include $(REL_TOP)/config.mak"

all: | $(SRC_DIRS) $(BUILD_DIR) $(BUILD_DIR)/Makefile $(BUILD_DIR)/config.mak
	cd $(BUILD_DIR) && $(MAKE) $@

install: | $(SRC_DIRS) $(BUILD_DIR) $(BUILD_DIR)/Makefile $(BUILD_DIR)/config.mak
	cd $(BUILD_DIR) && $(MAKE) OUTPUT=$(OUTPUT) $@
	@# vendored fortify-headers → <sysroot>/include/fortify (see patches/gcc-*/0014)
	mkdir -p $(OUTPUT)/$(TARGET)/include/fortify
	cp -R fortify-headers/include/. $(OUTPUT)/$(TARGET)/include/fortify/
	$(if $(STAGE2_RELOCATE),$(CURDIR)/stage2/strip-host "$(OUTPUT)")
	$(if $(STAGE2_RELOCATE),$(CURDIR)/stage2/relocate "$(OUTPUT)")

endif

.SECONDARY:
