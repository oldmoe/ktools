require 'mkmf'

def add_define(name)
  $defs.push("-D#{name}")
end

add_define "HAVE_TBR" if have_func('rb_thread_blocking_region')# and have_macro('RUBY_UBF_IO', 'ruby.h')
add_define "HAVE_INOTIFY" if inotify = have_func('inotify_init', 'sys/inotify.h')
add_define "HAVE_KQUEUE" if have_header("sys/event.h") and have_header("sys/queue.h")
add_define "HAVE_OLD_INOTIFY" if !inotify && have_macro('__NR_inotify_init', 'sys/syscall.h')

if have_header('sys/epoll.h')
  File.open("hasEpollTest.c", "w") {|f|
    f.puts "#include <sys/epoll.h>"
    f.puts "int main() { epoll_create(1024); return 0;}"
  }
  (e = system( "gcc hasEpollTest.c -o hasEpollTest " )) and (e = $?.to_i)
  `rm -f hasEpollTest.c hasEpollTest`
  add_define 'HAVE_EPOLL' if e == 0
end

case RUBY_PLATFORM

when /darwin/
  ldshared = "$(CC) " + CONFIG['LDSHARED'].split[1..-1].join(' ')
else
  ldshared = CONFIG['LDSHARED']
end

cc = `which #{CONFIG['CC']}`.chomp

objs = "ktools.o "
objs << "kqueue.o " if $defs.include?("-DHAVE_KQUEUE")
objs << "inotify.o " if $defs.include?("-DHAVE_INOTIFY")
objs << "epoll.o " if $defs.include?("-DHAVE_EPOLL")

File.open("Makefile", 'w') do |f|
  f.puts "CC = #{cc}"
  f.puts "LDSHARED = #{ldshared}"
  f.puts "CFLAGS = #{CONFIG['CFLAGS']} #{$defs.join(' ')}"
  f.puts "CLEANFILES = *.o *.bundle *.so"
  f.puts "DLLIB = ktools.#{CONFIG['DLEXT']}"
  f.puts "OBJS = #{objs}"
  f.puts "all : $(DLLIB)"
  f.puts "clean : 
		rm -f $(CLEANFILES)

$(DLLIB) : $(OBJS)
		$(LDSHARED) -o $@ $(OBJS)

$(OBJS) : *.h
"
end