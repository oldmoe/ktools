#include "ktools.h"
#include <errno.h>

int get_errno()
{
  return errno;
}

int have_kqueue()
{
	#ifdef HAVE_KQUEUE
	return 1;
	#else
	return 0;
	#endif
}

int have_epoll()
{
	#ifdef HAVE_EPOLL
	return 1;
	#else
	return 0;
	#endif
}

int have_inotify()
{
	#ifdef HAVE_INOTIFY
	return 1;
	#else
	return 0;
	#endif
}

int have_netlink()
{
	#ifdef HAVE_NETLINK
	return 1;
	#else
	return 0;
	#endif
}
