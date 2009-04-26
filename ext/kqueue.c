#ifdef HAVE_KQUEUE

#include "kqueue.h"

void wrap_evset(struct kevent *kev, unsigned int ident, short filter, unsigned short flags, unsigned int fflags, int data, void *udata)
{
	EV_SET(kev, ident, filter, flags, fflags, data, udata);
}

#endif
