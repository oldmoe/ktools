module Kernel
  extend FFI::Library
  ffi_lib Dir.glob("ext/ktools.*").select{|x| x =~ /\.so$/ || x =~ /\.bundle$/}.first

  # Tells us from Ruby whether or not we have built with support for these libraries
  %w[epoll kqueue inotify netlink].each do |m|
    attach_function "have_#{m}".to_sym, [], :int
    define_method("have_#{m}?") { (self.send "have_#{m}") > 0 ? true : false }
  end

  attach_function :get_errno, [], :int

  # Returns the current system errno as a Ruby Errno object
  def errno
    SystemCallError.new(get_errno)
  end

end
