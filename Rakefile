require 'rake' unless defined?(Rake)
require 'mkmf'
include Config

task :default => [:build, :test]
task :build => [:clean, :config, :objs, :shared]

def add_define(name)
  $ktools_defines.push("-D#{name}")
end

task :config do
  $ktools_defines = []
  $ktools_dlext = RbConfig::expand(CONFIG['DLEXT'])
  (add_define "HAVE_TBR" and build_against_ruby_stuff = true) if have_func('rb_thread_blocking_region')
  add_define "HAVE_KQUEUE" if have_header("sys/event.h") and have_header("sys/queue.h")
  #add_define "HAVE_INOTIFY" if inotify = have_func('inotify_init', 'sys/inotify.h')
  #add_define "HAVE_OLD_INOTIFY" if !inotify && have_macro('__NR_inotify_init', 'sys/syscall.h')

  if have_header('sys/epoll.h')
    File.open("hasEpollTest.c", "w") {|f|
      f.puts "#include <sys/epoll.h>"
      f.puts "int main() { epoll_create(1024); return 0;}"
    }
    (e = system( "gcc hasEpollTest.c -o hasEpollTest " )) and (e = $?.to_i)
    `rm -f hasEpollTest.c hasEpollTest`
    add_define 'HAVE_EPOLL' if e == 0
  end

  $ktools_cc = `which #{RbConfig::expand(CONFIG["CC"])}`.chomp
  $ktools_cflags = RbConfig::expand(CONFIG['CFLAGS']).split(" ")
  $ktools_cflags.delete("$(cflags)")
  $ktools_cflags = $ktools_cflags.join(" ")
  $ktools_srcs = ["ktools.c"]
  $ktools_srcs << "kqueue.c" if $ktools_defines.include?("-DHAVE_KQUEUE")
  $ktools_srcs << "inotify.c" if $ktools_defines.include?("-DHAVE_INOTIFY")
  $ktools_srcs << "epoll.c" if $ktools_defines.include?("-DHAVE_EPOLL")
  $ktools_srcs << "netlink.c" if $ktools_defines.include?("-DHAVE_NETLINK")

  if CONFIG["rubyhdrdir"]
    hdrdir = RbConfig::expand(CONFIG["rubyhdrdir"])
    $ktools_includes = "-I. -I#{hdrdir}/#{RbConfig::expand(CONFIG["sitearch"])} -I#{hdrdir}" if build_against_ruby_stuff
  end

  $ktools_ldshared = RbConfig::expand(CONFIG['LDSHARED'])
  $ktools_ldshared << " -o ../lib/ktools.#{$ktools_dlext} " + $ktools_srcs.collect{|x| x.gsub(/\.c/, ".o")}.join(" ")
  $ktools_ldshared << " -L#{RbConfig::expand(CONFIG['libdir'])} #{RbConfig::expand(CONFIG['LIBRUBYARG_SHARED'])}" if build_against_ruby_stuff
end

task :clean do
  chdir "ext" do
    sh "rm -f *.o *.bundle *.so"
  end
  chdir "lib" do
    sh "rm -f *.o *.bundle *.so"
  end
end

task :test do
  require 'lib/ktools'
  require 'bacon'
  Bacon.summary_on_exit
  load "tests/test_kqueue.rb" if Kernel.have_kqueue?
  load "tests/test_epoll.rb" if Kernel.have_epoll?
end

task :objs do
  chdir "ext" do
    $ktools_srcs.each {|c| sh "#{$ktools_cc} #{$ktools_cflags} #{$ktools_defines.join(' ')} #{$ktools_includes} -c #{c}"}
  end
end

task :shared do
  chdir "ext" do
    sh "#{$ktools_ldshared}"
  end
end
