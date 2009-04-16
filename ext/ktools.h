#ifndef KTOOLS_H
#define KTOOLS_H

#ifdef HAVE_EPOLL
#include "epoll.h"
#endif

#ifdef HAVE_KQUEUE
#include "kqueue.h"
#endif

/*#ifdef HAVE_NETLINK
#include "netlink.h"
#endif

#ifdef HAVE_INOTIFY
#include "inotify.h"
#endif*/

#endif
