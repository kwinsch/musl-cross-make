/* stage2 launcher — portable-mode wrapper for the musl-hosted host tools.
 *
 * Replaces the old /bin/sh trampoline. Compiled fully static against musl (no
 * PT_INTERP, no shared deps) so it runs on any host, then execs <self>.real
 * through the bundled musl loader:
 *
 *     <D>/lib/<loader> --argv0 <self> --library-path <D>/lib <self>.real args...
 *
 * where <D> is the first ancestor dir of the launcher that contains
 * lib/<loader>. Being a real ELF (not a script) means `file gcc` reports an
 * executable and there is no per-invocation shell fork.
 *
 * --argv0 <self>: present under the PUBLIC name, never <tool>.real. GCC copies
 * argv[0] into COLLECT_GCC and re-spawns it directly for LTO/LTRANS; the public
 * name routes that re-spawn back through this launcher (which supplies the
 * loader), so the kernel never execs <tool>.real — whose PT_INTERP is a
 * neutralized stub that does not exist on disk.
 *
 * MCM_LOADER is baked at compile time (e.g. "ld-musl-x86_64.so.1").
 */
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>

#ifndef MCM_LOADER
#define MCM_LOADER "ld-musl-x86_64.so.1"
#endif

static void die(const char *msg) { perror(msg); _exit(127); }

int main(int argc, char **argv)
{
	char self[PATH_MAX];
	ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
	if (n < 0) die("stage2-launcher: readlink /proc/self/exe");
	self[n] = '\0';

	/* real = self + ".real" */
	char real[PATH_MAX];
	if ((size_t)n + sizeof ".real" > sizeof real) {
		fprintf(stderr, "stage2-launcher: path too long\n");
		return 127;
	}
	memcpy(real, self, (size_t)n);
	memcpy(real + n, ".real", sizeof ".real"); /* copies trailing NUL */

	/* Walk up from dirname(self) to the first ancestor with lib/<loader>.
	 * When the target triple matches the host (x86_64-stage2), tools under
	 * <triple>/bin/ hit the TARGET SYSROOT's lib/<loader> first — same arch,
	 * same musl, so it works, but it is the sysroot's libc that runs them.
	 * Keep in mind on a musl version bump. */
	char dir[PATH_MAX];
	memcpy(dir, self, (size_t)n + 1);
	char *slash = strrchr(dir, '/');
	if (!slash) { fprintf(stderr, "stage2-launcher: bad self path %s\n", self); return 127; }
	*slash = '\0';

	char loader[PATH_MAX];
	char libdir[PATH_MAX];
	for (;;) {
		int w = snprintf(loader, sizeof loader, "%s/lib/%s", dir, MCM_LOADER);
		if (w > 0 && (size_t)w < sizeof loader && access(loader, X_OK) == 0) {
			snprintf(libdir, sizeof libdir, "%s/lib", dir);
			break;
		}
		char *s = strrchr(dir, '/');
		if (!s || s == dir) {
			fprintf(stderr, "stage2-launcher: no bundled musl loader above %s\n", self);
			return 127;
		}
		*s = '\0';
	}

	/* loader --argv0 <self> --library-path <libdir> <real> [orig args...] */
	char **nargv = malloc((size_t)(argc + 6) * sizeof *nargv);
	if (!nargv) die("stage2-launcher: malloc");
	int i = 0;
	nargv[i++] = loader;
	nargv[i++] = "--argv0";
	nargv[i++] = self;
	nargv[i++] = "--library-path";
	nargv[i++] = libdir;
	nargv[i++] = real;
	for (int j = 1; j < argc; j++) nargv[i++] = argv[j];
	nargv[i] = NULL;

	execv(loader, nargv);
	die("stage2-launcher: execv loader");
	return 127;
}
