/* stage2 setinterp — in-place PT_INTERP rewrite for stage2 host tools.
 *
 *   setinterp FILE            print current interp and reserved size
 *   setinterp FILE NEWPATH    rewrite interp in place (must fit)
 *
 * Host tools are linked with a /./-padded -Wl,-dynamic-linker so PT_INTERP
 * reserves a fixed region (~512 bytes). Rewriting is then a plain string
 * overwrite inside that region — no section surgery, no patchelf: write
 * NEWPATH + NUL, zero-fill the remainder (the kernel only requires the last
 * byte of the segment to be NUL and reads the buffer as a C string).
 *
 * Deliberately strict: ELF64 little-endian x86_64 only (stage2 host tools are
 * always built by the x86_64 stage1), exactly one PT_INTERP, absolute NEWPATH.
 * Exit: 0 ok · 1 I/O or ELF format error · 2 usage · 3 NEWPATH does not fit.
 */
#include <elf.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_INTERP 4096 /* kernel rejects PT_INTERP p_filesz > PATH_MAX */

static const char *file;

static void die(const char *msg)
{
	fprintf(stderr, "setinterp: %s: %s", file ? file : "?", msg);
	if (errno)
		fprintf(stderr, " (%s)", strerror(errno));
	fputc('\n', stderr);
	exit(1);
}

static void xpread(int fd, void *buf, size_t n, off_t off, const char *what)
{
	ssize_t r = pread(fd, buf, n, off);
	if (r < 0)
		die(what);
	if ((size_t)r != n) {
		errno = 0;
		die("short read");
	}
}

int main(int argc, char **argv)
{
	if (argc != 2 && argc != 3) {
		fprintf(stderr, "usage: setinterp FILE [NEWPATH]\n");
		return 2;
	}
	file = argv[1];
	const char *newpath = argc == 3 ? argv[2] : NULL;

	if (newpath && newpath[0] != '/') {
		fprintf(stderr, "setinterp: NEWPATH must be absolute: %s\n", newpath);
		return 2;
	}

	int fd = open(file, newpath ? O_RDWR : O_RDONLY);
	if (fd < 0)
		die("open");

	Elf64_Ehdr eh;
	xpread(fd, &eh, sizeof eh, 0, "read ELF header");
	errno = 0;
	if (memcmp(eh.e_ident, ELFMAG, SELFMAG) != 0)
		die("not an ELF file");
	if (eh.e_ident[EI_CLASS] != ELFCLASS64 || eh.e_ident[EI_DATA] != ELFDATA2LSB)
		die("not ELF64 little-endian");
	if (eh.e_machine != EM_X86_64)
		die("not x86_64 (stage2 host tools are always x86_64)");
	if (eh.e_phentsize != sizeof(Elf64_Phdr) || eh.e_phnum == 0)
		die("bad program header table");

	Elf64_Phdr ph, interp_ph;
	int found = 0;
	for (int i = 0; i < eh.e_phnum; i++) {
		xpread(fd, &ph, sizeof ph, (off_t)eh.e_phoff + (off_t)i * sizeof ph,
		       "read program header");
		if (ph.p_type != PT_INTERP)
			continue;
		errno = 0;
		if (found)
			die("multiple PT_INTERP segments");
		interp_ph = ph;
		found = 1;
	}
	errno = 0;
	if (!found)
		die("no PT_INTERP segment");
	if (interp_ph.p_filesz < 2 || interp_ph.p_filesz > MAX_INTERP)
		die("implausible PT_INTERP size");

	char buf[MAX_INTERP];
	xpread(fd, buf, interp_ph.p_filesz, (off_t)interp_ph.p_offset,
	       "read interp");
	errno = 0;
	if (buf[interp_ph.p_filesz - 1] != '\0')
		die("PT_INTERP not NUL-terminated");

	if (!newpath) {
		printf("%s\n", buf);
		printf("reserved %llu used %zu\n",
		       (unsigned long long)interp_ph.p_filesz, strlen(buf) + 1);
		close(fd);
		return 0;
	}

	size_t need = strlen(newpath) + 1;
	if (need > interp_ph.p_filesz) {
		fprintf(stderr,
			"setinterp: %s: new interp needs %zu bytes, only %llu reserved\n",
			file, need, (unsigned long long)interp_ph.p_filesz);
		close(fd);
		return 3;
	}

	memset(buf, 0, interp_ph.p_filesz);
	memcpy(buf, newpath, need);
	ssize_t w = pwrite(fd, buf, interp_ph.p_filesz, (off_t)interp_ph.p_offset);
	if (w < 0)
		die("write interp");
	if ((size_t)w != interp_ph.p_filesz) {
		errno = 0;
		die("short write");
	}
	if (close(fd) != 0)
		die("close");
	return 0;
}
