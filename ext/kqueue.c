#ifdef HAVE_KQUEUE

#include "kqueue.h"

void ev_set(struct kevent *kev, unsigned int ident, short filter, unsigned short flags, unsigned int fflags, int data, void *udata)
{
	EV_SET(kev, ident, filter, flags, fflags, data, udata);
}

#endif
