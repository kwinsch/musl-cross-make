#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

// std::thread rides libstdc++'s gthread layer on top of static musl pthreads
// — a different (and more breakable) path than the C pthread test.
int main()
{
	constexpr int nthreads = 4;
	constexpr int loops = 10000;
	long counter = 0;
	std::mutex lock;
	std::vector<std::thread> threads;

	for (int i = 0; i < nthreads; i++)
		threads.emplace_back([&] {
			for (int j = 0; j < loops; j++) {
				std::lock_guard<std::mutex> g(lock);
				++counter;
			}
		});
	for (auto &t : threads)
		t.join();
	std::cout << "counter=" << counter << '\n';
	return 0;
}
