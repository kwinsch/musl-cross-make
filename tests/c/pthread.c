#include <pthread.h>
#include <stdio.h>

/* Static musl's most fragile area historically: pthreads pulled from libc.a
 * via weak refs. Real contention across threads, not just a create/join. */

#define NTHREADS 4
#define LOOPS 10000

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static long counter;

static void *worker(void *arg)
{
	(void)arg;
	for (int i = 0; i < LOOPS; i++) {
		pthread_mutex_lock(&lock);
		counter++;
		pthread_mutex_unlock(&lock);
	}
	return 0;
}

int main(void)
{
	pthread_t t[NTHREADS];

	for (int i = 0; i < NTHREADS; i++)
		if (pthread_create(&t[i], 0, worker, 0))
			return 1;
	for (int i = 0; i < NTHREADS; i++)
		if (pthread_join(t[i], 0))
			return 1;
	printf("counter=%ld\n", counter);
	return 0;
}
