#ifdef HAVE_KQUEUE

#include "kqueue.h"
#ifdef HAVE_TBR
#include <ruby.h>
#endif

void ev_set(struct kevent *kev, unsigned int ident, short filter, unsigned short flags, unsigned int fflags, int data, void *udata)
{
	EV_SET(kev, ident, filter, flags, fflags, data, udata);
}

int wrap_kqueue()
{
  int r;
  #ifdef HAVE_TBR
  rb_thread_blocking_region((rb_blocking_function_t *) tbr_kqueue, &r, RUBY_UBF_IO, 0);
  #else
  r = kqueue();
  #endif
  return r;
}

void tbr_kqueue(int *i)
{
  *i = kqueue();
}

#endif
