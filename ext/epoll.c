#ifdef HAVE_EPOLL

#include "epoll.h"

#ifdef HAVE_TBR
#include <ruby.h>
#endif

int wrap_epoll_wait(int epfd, struct epoll_event *event, int maxevents, int timeout)
{
  #ifdef HAVE_TBR
  struct wrapped_epoll_event epevent;
  epevent.epfd = epfd;
  epevent.event = event;
  epevent.maxevents = maxevents;
  epevent.timeout = timeout;
  epevent.result = -1;
  rb_thread_blocking_region((rb_blocking_function_t *) tbr_epoll_wait, &epevent, RUBY_UBF_IO, 0);
  return epevent.result;
  #else
  return epoll_wait(epfd, event, maxevents, timeout);
  #endif
}

#ifdef HAVE_TBR
void tbr_epoll_wait(struct wrapped_epoll_event *event)
{
  event->result = epoll_wait(event->epfd, event->event, event->maxevents, event->timeout);
}
#endif

#endif
