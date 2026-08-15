#include <iostream>
#include <vector>
#include <numeric>

int main()
{
	std::vector<int> v{1, 2, 3, 4};
	std::cout << "hello from c++ " << std::accumulate(v.begin(), v.end(), 0) << '\n';
	return 0;
}
