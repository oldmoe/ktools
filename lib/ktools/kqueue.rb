module Kernel

  class Kqueue
    extend FFI::Library

    class Kevent < FFI::Struct
      layout :ident, :uint, 
      :filter, :short, 
      :flags, :ushort, 
      :fflags, :uint, 
      :data, :int, 
      :udata, :pointer
    end

    class Timespec < FFI::Struct
      layout :tv_sec, :long,
        :tv_nsec, :long
    end

    kqc = FFI::ConstGenerator.new do |c|
      c.include 'sys/event.h'
      c.const("EVFILT_READ")
      c.const("EVFILT_WRITE")
      c.const("EVFILT_AIO")
      c.const("EVFILT_VNODE")
      c.const("EVFILT_PROC")
      c.const("EVFILT_SIGNAL")
      c.const("EVFILT_TIMER")
      c.const("EVFILT_MACHPORT")
      c.const("EVFILT_FS")
      c.const("EVFILT_SYSCOUNT")
      c.const("EV_ADD")
      c.const("EV_DELETE")
      c.const("EV_ENABLE")
      c.const("EV_DISABLE")
      c.const("EV_RECEIPT")
      c.const("EV_ONESHOT")
      c.const("EV_CLEAR")
      c.const("EV_SYSFLAGS")
      c.const("EV_FLAG0")
      c.const("EV_FLAG1")
      c.const("EV_EOF")
      c.const("EV_ERROR")
      c.const("EV_POLL")
      c.const("EV_OOBAND")
      c.const("NOTE_LOWAT")
      c.const("NOTE_DELETE")
      c.const("NOTE_WRITE")
      c.const("NOTE_EXTEND")
      c.const("NOTE_ATTRIB")
      c.const("NOTE_LINK")
      c.const("NOTE_RENAME")
      c.const("NOTE_REVOKE")
      c.const("NOTE_EXIT")
      c.const("NOTE_FORK")
      c.const("NOTE_EXEC")
      c.const("NOTE_REAP")
      c.const("NOTE_SIGNAL")
      c.const("NOTE_PDATAMASK")
      c.const("NOTE_PCTRLMASK")
      c.const("NOTE_SECONDS")
      c.const("NOTE_USECONDS")
      c.const("NOTE_NSECONDS")
      c.const("NOTE_ABSOLUTE")
      c.const("NOTE_TRACK")
      c.const("NOTE_TRACKERR")
      c.const("NOTE_CHILD")
    end

    eval kqc.to_ruby

    KQ_FILTERS = {
      :read => EVFILT_READ,
      :write => EVFILT_WRITE,
      :file => EVFILT_VNODE,
      :process => EVFILT_PROC,
      :signal => EVFILT_SIGNAL
    }

    KQ_FLAGS = {
      :add => EV_ADD,
      :enable => EV_ENABLE,
      :disable => EV_DISABLE,
      :delete => EV_DELETE,
      :oneshot => EV_ONESHOT,
      :clear => EV_CLEAR
    }

    KQ_FFLAGS = {
      :delete => NOTE_DELETE,
      :write => NOTE_WRITE,
      :extend => NOTE_EXTEND,
      :attrib => NOTE_ATTRIB,
      :link => NOTE_LINK,
      :rename => NOTE_RENAME,
      :revoke => NOTE_REVOKE,
      :exit => NOTE_EXIT,
      :fork => NOTE_FORK,
      :exec => NOTE_EXEC
    }

    # Leopard has these, Tiger does not.
    KQ_FLAGS[:receipt] = EV_RECEIPT if const_defined?("EV_RECEIPT")
    KQ_FFLAGS[:signal] = NOTE_SIGNAL if const_defined?("NOTE_SIGNAL")
    KQ_FFLAGS[:reap] = NOTE_REAP if const_defined?("NOTE_REAP")

    # Had to write a wrapper for EV_SET since its a macro
    attach_function :ev_set, :wrap_evset, [:pointer, :uint, :short, :ushort, :uint, :int, :pointer], :void
    # Attach directly to kqueue function, no wrapper needed
    attach_function :kqueue, [], :int
    # We wrap kqueue and kevent because we use rb_thread_blocking_region when it's available in MRI
    attach_function :kevent, :wrap_kevent, [:int, :pointer, :int, :pointer, :int, Timespec], :int

    # We provide the raw C interface above. Now we OO-ify it.

    # Creates a new kqueue object. Will raise an error if the operation fails.
    def initialize
      @fds = {}
      @kqfd = kqueue
      raise SystemCallError.new("Error creating kqueue descriptor", get_errno) unless @kqfd > 0
    end

    # Add events on a file to the Kqueue. kqueue requires that a file actually be opened (to get a descriptor)
    # before it can be monitored. You can pass a File object here, or a String of the pathname, in which
    # case we'll try to open the file for you. In either case, a File object will be returned as the :target 
    # in the event returned by #poll. Valid events here are as follows, using descriptions from the kqueue man pages:
    #
    # * :delete - "The unlink() system call was called on the file referenced by the descriptor."
    # * :write  - "A write occurred on the file referenced by the descriptor."
    # * :extend - "The file referenced by the descriptor was extended."
    # * :attrib - "The file referenced by the descriptor had its attributes changed."
    # * :link   - "The link count on the file changed."
    # * :rename - "The file referenced by the descriptor was renamed."
    # * :revoke - "Access to the file was revoked via revoke(2) or the underlying fileystem was unmounted."
    #
    # Example:
    #  irb(main):001:0> require 'ktools'
    #  => true
    #  irb(main):002:0> file = Tempfile.new("kqueue-test")
    #  => #<File:/tmp/kqueue-test20090417-602-evm5wc-0>
    #  irb(main):003:0> kq = Kqueue.new
    #  => #<Kernel::Kqueue:0x4f0aec @kqfd=5, @fds={}>
    #  irb(main):004:0> kq.add_file(file, :events => [:write, :delete])
    #  => true
    #  irb(main):005:0> kq.poll
    #  => []
    #  irb(main):006:0> file.delete
    #  => #<File:/tmp/kqueue-test20090417-602-evm5wc-0>
    #  irb(main):007:0> kq.poll
    #  => [{:type=>:file, :target=>#<File:/tmp/kqueue-test20090417-602-evm5wc-0>, :event=>:delete}]
    #  irb(main):008:0> file.close and kq.close 
    #  => nil
    def add_file(file, options={})
      fflags, flags = options.values_at :events, :flags
      raise ArgumentError.new("must specify which file events to watch for") unless fflags

      file = file.kind_of?(File) || file.kind_of?(Tempfile) ? file : File.open(file, 'r')

      k = Kevent.new
      flags = flags ? flags.inject(0){|m,i| m | KQ_FLAGS[i] } : EV_CLEAR
      fflags = fflags.inject(0){|m,i| m | KQ_FFLAGS[i] }
      ev_set(k, file.fileno, EVFILT_VNODE, EV_ADD | flags, fflags, 0, nil)

      if kevent(@kqfd, k, 1, nil, 0, nil) == -1
        return false
      else
        @fds[file.fileno] = {:target => file, :kevent => k}
        return true
      end
    end

    # Add events to a socket-style descriptor (socket or pipe). Supported events are:
    #
    # * :read - The descriptor has become readable.
    # * :write - The descriptor has become writeable.
    #
    # See the kqueue manpage for how behavior differs depending on the descriptor types. 
    # In general, you shouldn't have to worry about it.
    #
    # Example:
    #  irb(main):001:0> require 'ktools'
    #  => true
    #  irb(main):002:0> r, w = IO.pipe
    #  => [#<IO:0x4fa90c>, #<IO:0x4fa880>]
    #  irb(main):003:0> kq = Kqueue.new
    #  => #<Kernel::Kqueue:0x4f43a4 @kqfd=6, @fds={}>
    #  irb(main):004:0> kq.add_socket(r, :events => [:read, :write])
    #  => true
    #  irb(main):005:0> kq.poll
    #  => []
    #  irb(main):006:0> w.write "foo"
    #  => 3
    #  irb(main):007:0> kq.poll
    #  => [{:type=>:socket, :target=>#<IO:0x4fa90c>, :event=>:read}]
    #  irb(main):008:0> [r, w, kq].each {|i| i.close}
    def add_socket(io, options={})
      filters, flags = options.values_at :events, :flags
      flags = flags ? flags.inject(0){|m,i| m | KQ_FLAGS[i] } : EV_CLEAR
      filters = filters ? filters.inject(0){|m,i| m | KQ_FILTERS[i] } : EVFILT_READ | EVFILT_WRITE

      k = Kevent.new
      ev_set(k, io.fileno, filters, EV_ADD | flags, 0, 0, nil)

      if kevent(@kqfd, k, 1, nil, 0, nil) == -1
        return false
      else
        @fds[io.fileno] = {:target => io, :kevent => k}
        return true
      end
    end

    # Poll for an event. Pass an optional timeout float as number of seconds to wait for an event. Default is 0.0 (do not wait).
    #
    # Using a timeout will block for the duration of the timeout. Under Ruby 1.9.1, we use rb_thread_blocking_region() under the
    # hood to allow other threads to run during this call. Prior to 1.9 though, we do not have native threads and hence this call
    # will block the whole interpreter (all threads) until it returns.
    #
    # This call returns a hash, similar to the following:
    #  => [{:type=>:socket, :target=>#<IO:0x4fa90c>, :event=>:read}]
    #
    # * :type - will be the type of event target, i.e. an event set with #add_file will have :type => :file
    # * :target - the 'target' or 'subject' of the event. This can be a File, IO, process or signal number.
    # * :event - the event that occurred on the target. This is one of the symbols you passed as :events => [:foo] when adding the event.
    def poll(timeout=0.0)
      k = Kevent.new
      t = Timespec.new
      t[:tv_sec] = timeout.to_i
      t[:tv_nsec] = ((timeout - timeout.to_i) * 1e9).to_i

      case kevent(@kqfd, nil, 0, k, 1, t)
      when -1
        [errno]
      when 0
        []
      else
        process_event(k)
      end
    end

    def process_event(k) #:nodoc:
      h = @fds[k[:ident]]
      return nil if h.nil?
      res = {:target => h[:target]}

      case k[:filter]
      when EVFILT_VNODE
        event = if k[:fflags] & NOTE_DELETE == NOTE_DELETE
          :delete
        elsif k[:fflags] & NOTE_WRITE == NOTE_WRITE
          :write
        elsif k[:fflags] & NOTE_EXTEND == NOTE_EXTEND
          :extend
        elsif k[:fflags] & NOTE_ATTRIB == NOTE_ATTRIB
          :attrib
        elsif k[:fflags] & NOTE_LINK == NOTE_LINK
          :link
        elsif k[:fflags] & NOTE_RENAME == NOTE_RENAME
          :rename
        elsif k[:fflags] & NOTE_REVOKE == NOTE_REVOKE
          :revoke
        end
        res.merge!({:type => :file, :event => event})
      when EVFILT_READ
        res.merge!({:type => :socket, :event => :read})
      when EVFILT_WRITE
        res.merge!({:type => :socket, :event => :write})
      end

      @fds.delete(k[:ident]) if k[:flags] & EV_ONESHOT == EV_ONESHOT
      [res]
    end

    # Delete events for the given event target
    def delete(target)
      ident = target.respond_to?(:fileno) ? target.fileno : target
      h = @fds[ident]
      return nil if h.nil?
      k = h[:kevent]
      ev_set(k, k[:ident], k[:filter], EV_DELETE, k[:fflags], 0, nil)
      kevent(@kqfd, k, 1, nil, 0, nil)
      @fds.delete(ident)
      return target
    end

    # Close the kqueue descriptor. This essentially shuts down your kqueue and renders all active events on this kqueue removed. 
    def close
      IO.for_fd(@kqfd).close
    end

  end
end
