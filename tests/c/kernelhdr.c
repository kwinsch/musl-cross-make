#include <linux/version.h>
#include <linux/netlink.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

/* The sysroot ships full linux-* UAPI headers (headers_install) that nothing
 * else compiles against. Guard the wiring at compile time and use the kernel
 * interfaces (epoll + eventfd) for real. */

#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 0, 0)
#error sysroot kernel headers are ancient
#endif

_Static_assert(sizeof(struct sockaddr_nl) == 12, "UAPI struct layout");

int main(void)
{
	uint64_t v = 7;
	int efd = eventfd(0, 0);
	int ep = epoll_create1(0);
	struct epoll_event ev = { .events = EPOLLIN }, got;

	if (efd < 0 || ep < 0)
		return 1;
	if (epoll_ctl(ep, EPOLL_CTL_ADD, efd, &ev) || write(efd, &v, 8) != 8)
		return 1;
	if (epoll_wait(ep, &got, 1, 1000) != 1 || !(got.events & EPOLLIN))
		return 1;
	v = 0;
	if (read(efd, &v, 8) != 8)
		return 1;
	printf("epoll eventfd %d\n", (int)v);
	close(efd);
	close(ep);
	return 0;
}
