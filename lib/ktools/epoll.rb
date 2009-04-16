module Kernel
  module Epoll
    extend FFI::Library

    class Epoll_data < FFI::Struct
      layout :ptr, :pointer,
        :fd, :int,
        :u32, :uint32,
        :u64, :uint64
    end

    class Epoll_event < FFI::Struct
      layout :events, :uint32,
        :data, :pointer

      def [] (key)
        key == :data ? Epoll_data.new(super(key)) : super(key)
      end
    end

    epc = FFI::ConstGenerator.new do |c|
      c.include('sys/epoll.h')
      c.const("EPOLLIN")
      c.const("EPOLLPRI")
      c.const("EPOLLOUT")
      c.const("EPOLLRDNORM")
      c.const("EPOLLRDBAND")
      c.const("EPOLLWRNORM")
      c.const("EPOLLWRBAND")
      c.const("EPOLLMSG")
      c.const("EPOLLERR")
      c.const("EPOLLHUP")
      c.const("EPOLLONESHOT")
      c.const("EPOLLET")
      c.const("EPOLL_CTL_ADD")
      c.const("EPOLL_CTL_DEL")
      c.const("EPOLL_CTL_MOD")
    end

    eval epc.to_ruby

    # Attach directly to epoll_create
    attach_function :epoll_create, [:int], :int
    # Attach directly to epoll_ctl
    attach_function :epoll_ctl, [:int, :int, :int, :pointer], :int
    # Attach to the epoll_wait wrapper so we can use rb_thread_blocking_region when possible
    attach_function :epoll_wait, :wrap_epoll_wait, [:int, :pointer, :int, :int], :int
  end
end
