#ifdef HAVE_KQUEUE

#include <sys/event.h>
#include <sys/queue.h>

#ifdef HAVE_TBR
struct wrapped_kevent {
  int kqfd;
  struct kevent *changelist;
  int nchanges;
  struct kevent *eventlist;
  int nevents;
  struct timespec *timeout;
  int result;
};

void tbr_kevent(struct wrapped_kevent*);
#endif

#endif