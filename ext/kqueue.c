#ifdef HAVE_KQUEUE

#include "kqueue.h"

#ifdef HAVE_TBR
#include <ruby.h>
#endif

void wrap_evset(struct kevent *kev, unsigned int ident, short filter, unsigned short flags, unsigned int fflags, int data, void *udata)
{
	EV_SET(kev, ident, filter, flags, fflags, data, udata);
}

int wrap_kqueue()
{
  #ifdef HAVE_TBR
  int r;
  rb_thread_blocking_region((rb_blocking_function_t *) tbr_kqueue, &r, RUBY_UBF_IO, 0);
  return r;
  #else
  return kqueue();
  #endif
}

#ifdef HAVE_TBR
void tbr_kqueue(int *i)
{
  *i = kqueue();
}
#endif

int wrap_kevent(int kqfd, struct kevent *changelist, int nchanges, struct kevent *eventlist, int nevents, struct timespec *timeout)
{
  #ifdef HAVE_TBR
  struct wrapped_kevent wevent;
  wevent.kqfd = kqfd;
  wevent.changelist = changelist;
  wevent.nchanges = nchanges;
  wevent.eventlist = eventlist;
  wevent.nevents = nevents;
  wevent.timeout = timeout;
  wevent.result = -1;
  rb_thread_blocking_region((rb_blocking_function_t *) tbr_kevent, &wevent, RUBY_UBF_IO, 0);
  return wevent.result;
  #else
  return kevent(kqfd, changelist, nchanges, eventlist, nevents, timeout);
  #endif
}

#ifdef HAVE_TBR
void tbr_kevent(struct wrapped_kevent *wevent)
{
  wevent->result = kevent(wevent->kqfd, wevent->changelist, wevent->nchanges, wevent->eventlist, wevent->nevents, wevent->timeout);
}
#endif

#endif
