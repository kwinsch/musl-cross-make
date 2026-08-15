#include <iostream>
#include <stdexcept>

// Exercises libstdc++ exception unwinding (the fdpic-unwind / cow-libstdc++
// patch territory) — "compiles" is not enough; this must actually unwind.
int main()
{
	try {
		throw std::runtime_error("boom");
	} catch (const std::exception &e) {
		std::cout << "caught " << e.what() << '\n';
	}
	return 0;
}
