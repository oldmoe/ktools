module Kernel
  class Epoll
    extend FFI::Library

    class Epoll_data < FFI::Union #:nodoc:
      layout :ptr, :pointer,
        :fd, :int,
        :u32, :uint32,
        :u64, :uint64
    end

    class Epoll_event < FFI::Struct #:nodoc:
      layout :events, :uint32,
        :data, Epoll_data
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

    # Missing in some kernel versions
    EP_FLAGS[:remote_hangup] = EPOLLRDHUP if const_defined?("EPOLLRDHUP")

    # Attach directly to epoll_create
    attach_function :epoll_create, [:int], :int
    # Attach directly to epoll_ctl
    attach_function :epoll_ctl, [:int, :int, :int, :pointer], :int
    attach_function :epoll_wait, [:int, :pointer, :int, :int], :int

    # Creates a new epoll event queue. Takes an optional size parameter (default 1024) that is a hint
    # to the kernel about how many descriptors it will be handling. Read man epoll_create for details 
    # on this. Raises an error if the operation fails.
    def initialize(size=1024)
      @fds = {}
      @epfd = epoll_create(size)
      raise SystemCallError.new("Error creating epoll descriptor", get_errno) unless @epfd > 0
      @epfd = IO.for_fd(@epfd)
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
    #  => [{:target=>#<IO:0x89be38c>, :events=>[:read], :type=>:socket}]
    #  irb(main):008:0> [r, w, ep].each{|x| x.close }
    def add_socket(target, options={})
      fdnum = target.respond_to?(:fileno) ? target.fileno : target
      events = (options[:events] + (options[:flags] || [])).inject(0){|m,i| m | EP_FLAGS[i]}

      ev = Epoll_event.new
      ev[:events] = events
      ev[:data][:fd] = fdnum

      if epoll_ctl(@epfd.fileno, EPOLL_CTL_ADD, fdnum, ev) == -1
        return false
      else
        @fds[fdnum] = {:target => target, :event => ev}
        return true
      end
    end

    # Poll for an event. Pass an optional timeout float as number of seconds to wait for an event. Default is 0.0 (do not wait).
    #
    # Using a timeout will block the current thread for the duration of the timeout. We use select() on the epoll descriptor and
    # then call epoll_wait() with 0 timeout, instead of blocking the whole interpreter with epoll_wait().
    #
    # This call returns an array of hashes, similar to the following:
    #  => [{:type=>:socket, :target=>#<IO:0x4fa90c>, :events=>[:read]}]
    #
    # * :type - will be the type of event target, i.e. an event set with #add_socket will have :type => :socket
    # * :target - the 'target' or 'subject' of the event. This can be a File, IO, process or signal number.
    # * :event - the event that occurred on the target. This is one or more of the symbols you passed as :events => [:foo] when adding the event.
    #
    # Note: even though epoll only supports :socket style descriptors, we keep :type for consistency with other APIs.
    def poll(timeout=0.0)
      ary = FFI::MemoryPointer.new(Epoll_event, 1024)

      r, w, e = IO.select([@epfd], nil, nil, timeout)

      if r.nil? || r.empty?
        return []
      else
        case (count = epoll_wait(@epfd.fileno, ary, 1024, 0))
        when -1
          [errno]
        when 0
          []
        else
          res = []
          count.times{|i| res << process_event(Epoll_event.new(ary[i]))}
          res
        end
      end
    end

    def process_event(ev) #:nodoc:
      h = @fds[ev[:data][:fd]]
      return nil if h.nil?
      events = []
      events << :read if ev[:events] & EPOLLIN == EPOLLIN
      events << :write if ev[:events] & EPOLLOUT == EPOLLOUT
      events << :priority if ev[:events] & EPOLLPRI == EPOLLPRI
      events << :error if ev[:events] & EPOLLERR == EPOLLERR
      events << :hangup if ev[:events] & EPOLLHUP == EPOLLHUP
      events << :remote_hangup if Epoll.const_defined?("EPOLLRDHUP") and ev[:events] & EPOLLRDHUP == EPOLLRDHUP
      events << :oneshot if h[:event][:events] & EPOLLONESHOT == EPOLLONESHOT
      delete(:socket, h[:target]) if events.include?(:oneshot) || events.include?(:hangup) || events.include?(:remote_hangup)
      {:target => h[:target], :events => events, :type => :socket}
    end

    # Stop generating events for the given type and event target, ie:
    #  ep.delete(:socket, sock)
    #
    # Note: even though epoll only supports :socket style descriptors, we keep this for consistency with other APIs.
    def delete(type, target)
      ident = target.respond_to?(:fileno) ? target.fileno : target
      h = @fds[ident]
      return false if h.nil?
      epoll_ctl(@epfd.fileno, EPOLL_CTL_DEL, ident, h[:event])
      @fds.delete(ident)
      return true
    end

    def close
      @epfd.close
    end

  end
end
