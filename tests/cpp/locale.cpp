// std::locale with UTF-8 names must not throw on musl: libstdc++'s generic
// locale model used to reject every name but "C" (patches/gcc-*/0022), so
// std::locale("C.UTF-8") -- and std::locale("") under LANG=C.UTF-8, a common
// container default -- aborted static C++ programs.
#include <cstdio>
#include <locale>
#include <stdexcept>

int main() {
    const char *names[] = {"C", "C.UTF-8", "en_US.UTF-8"};
    for (const char *n : names) {
        try {
            std::locale l(n);
        } catch (const std::runtime_error &) {
            std::printf("cpp locale: FAIL (%s throws)\n", n);
            return 1;
        }
    }
    std::printf("cpp locale: ok\n");
    return 0;
}
