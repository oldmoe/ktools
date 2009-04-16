#ifdef HAVE_EPOLL

#include <sys/epoll.h>

#ifdef HAVE_TBR
struct wrapped_epoll_event {
  int epfd;
  struct epoll_event *event;
  int maxevents;
  int timeout;
  int result;
};

void tbr_epoll_wait(struct wrapped_epoll_event*);
#endif

#endif
