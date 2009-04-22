module Kernel
  class Epoll
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

      def [] key
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
      c.const("EPOLLRDHUP")
      c.const("EPOLLONESHOT")
      c.const("EPOLLET")
      c.const("EPOLL_CTL_ADD")
      c.const("EPOLL_CTL_DEL")
      c.const("EPOLL_CTL_MOD")
    end

    eval epc.to_ruby

    EP_FLAGS = {
      :read => EPOLLIN,
      :write => EPOLLOUT,
      :hangup => EPOLLHUP,
      :priority => EPOLLPRI,
      :edge => EPOLLET,
      :oneshot => EPOLLONESHOT,
      :error => EPOLLERR
    }

    EP_FLAGS[:remote_hangup] = EPOLLRDHUP if const_defined?("EPOLLRDHUP")

    # Attach directly to epoll_create
    attach_function :epoll_create, [:int], :int
    # Attach directly to epoll_ctl
    attach_function :epoll_ctl, [:int, :int, :int, :pointer], :int
    # Attach to the epoll_wait wrapper so we can use rb_thread_blocking_region when possible
    attach_function :epoll_wait, :wrap_epoll_wait, [:int, :pointer, :int, :int], :int

    # Creates a new epoll event queue. Takes an optional size parameter (default 1024) that is a hint
    # to the kernel about how many descriptors it will be handling. Read man epoll_create for details 
    # on this. Raises an error if the operation fails.
    def initialize(size=1024)
      @fds = {}
      @epfd = epoll_create(size)
      raise SystemCallError.new("Error creating epoll descriptor", get_errno) unless @epfd > 0
    end

    # Generic method for adding events. This simply calls the proper add_foo method specified by the type symbol.
    # Example:
    #  ep.add(:socket, sock, :events => [:read])
    #  calls -> ep.add_socket(sock, events => [:read])
    #
    # Note: even though epoll only supports :socket style descriptors, we keep this for consistency with other APIs.
    def add(type, target, options={})
      case type
      when :socket
        add_socket(target, options)
      else
        raise ArgumentError.new("Epoll only supports socket style descriptors")
      end
    end

    # Add events to a socket-style descriptor (socket or pipe). Your target can be either
    # an IO object (socket, pipe), or a file descriptor number.
    #
    # Supported :events are:
    #
    # * :read - The descriptor has become readable.
    # * :write - The descriptor has become writeable.
    # * :priority - There is urgent data available for read operations.
    # * :error - Error condition happened on the associated file descriptor. (Always active)
    # * :hangup - Hang up happened on the associated file descriptor. (Always active)
    # * :remote_hangup - Stream socket peer closed the connection, or shut down writing half of connection. (Missing from some kernel verions)
    #
    # Supported :flags are:
    #
    # * :edge - Sets the Edge Triggered behavior for the associated file descriptor. (see manpage)
    # * :oneshot - Sets the one-shot behaviour for the associated file descriptor. (Event only fires once)
    #
    # Example:
    #
    #  irb(main):001:0> require 'ktools'
    #  => true
    #  irb(main):002:0> r, w = IO.pipe
    #  => [#<IO:0x89be38c>, #<IO:0x89be378>]
    #  irb(main):003:0> ep = Epoll.new
    #  => #<Kernel::Epoll:0x89bca3c @fds={}, @epfd=5>
    #  irb(main):004:0> ep.add(:socket, r, :events => [:read])
    #  => true
    #  irb(main):005:0> ep.poll
    #  => []
    #  irb(main):006:0> w.write 'foo'
    #  => 3
    #  irb(main):007:0> ep.poll
    #  => [{:target=>#<IO:0x89be38c>, :event=>:read, :type=>:socket}]
    #  irb(main):008:0> [r, w, ep].each{|x| x.close }
    def add_socket(target, options={})
      fdnum = target.respond_to?(:fileno) ? target.fileno : target
      events = (options[:events] + (options[:flags] || [])).inject(0){|m,i| m | EP_FLAGS[i]}

      ev = Epoll_event.new
      ev[:events] = events
      ev[:data] = Epoll_data.new
      ev[:data][:fd] = fdnum

      if epoll_ctl(@epfd, EPOLL_CTL_ADD, fdnum, ev) == -1
        return false
      else
        @fds[fdnum] = {:target => target, :event => ev}
        return true
      end
    end

    # Poll for an event. Pass an optional timeout float as number of seconds to wait for an event. Default is 0.0 (do not wait).
    #
    # Using a timeout will block for the duration of the timeout. Under Ruby 1.9.1, we use rb_thread_blocking_region() under the
    # hood to allow other threads to run during this call. Prior to 1.9 though, we do not have native threads and hence this call
    # will block the whole interpreter (all threads) until it returns.
    #
    # This call returns an array of hashes, similar to the following:
    #  => [{:type=>:socket, :target=>#<IO:0x4fa90c>, :event=>:read}]
    #
    # * :type - will be the type of event target, i.e. an event set with #add_socket will have :type => :socket
    # * :target - the 'target' or 'subject' of the event. This can be a File, IO, process or signal number.
    # * :event - the event that occurred on the target. This is one of the symbols you passed as :events => [:foo] when adding the event.
    #
    # Note: even though epoll only supports :socket style descriptors, we keep :type for consistency with other APIs.
    def poll(timeout=0.0)
      timeout = (timeout * 1000).to_i
      ev = Epoll_event.new
      case epoll_wait(@epfd, ev, 1, timeout)
      when -1
        [errno]
      when 0
        []
      else
        [process_event(ev)]
      end
    end

    def process_event(ev) #:nodoc:
      h = @fds[ev[:data][:fd]]
      return nil if h.nil?

      event = if ev[:events] & EPOLLIN == EPOLLIN
        :read
      elsif ev[:events] & EPOLLOUT == EPOLLOUT
        :write
      elsif ev[:events] & ERPOLLPRI == EPOLLPRI
        :priority
      elsif ev[:events] & EPOLLERR == EPOLLERR
        :error
      elsif ev[:events] & EPOLLHUP == EPOLLHUP
        :hangup
      elsif Epoll.const_defined?("EPOLLRDHUP") and ev[:events] & EPOLLRDHUP == EPOLLRDHUP
        :remote_hangup
      end

      delete(:socket, h[:target]) if ev[:events] & EPOLLONESHOT == EPOLLONESHOT
      {:target => h[:target], :event => event, :type => :socket}
    end

    # Stop generating events for the given type and event target, ie:
    #  ep.delete(:socket, sock)
    #
    # Note: even though epoll only supports :socket style descriptors, we keep this for consistency with other APIs.
    def delete(type, target)
      ident = target.respond_to?(:fileno) ? target.fileno : target
      h = @fds[ident]
      return false if h.nil?
      epoll_ctl(@epfd, EPOLL_CTL_DEL, ident, h[:event])
      return true
    end

    def close
      IO.for_fd(@epfd).close
    end

  end
end
