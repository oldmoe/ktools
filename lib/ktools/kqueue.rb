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
      :attributes => NOTE_ATTRIB,
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

    def initialize
      @fds = {}
      @kqfd = kqueue
      raise SystemCallError.new("Error creating kqueue descriptor", get_errno) unless @kqfd > 0
    end

    def add_file(file, options={})
      fflags, flags = options.values_at :events, :flags
      raise ArgumentError.new("must specify which file events to watch for") unless fflags

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

    # Pass an optional timeout
    def poll(timeout=0)
      k = Kevent.new
      t = Timespec.new
      t[:tv_sec] = timeout
      case kevent(@kqfd, nil, 0, k, 1, t)
      when -1
        [errno]
      when 0
        []
      else
        process_event(k)
      end
    end

    def process_event(k)
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
          :attributes
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

    # Delete all events for this IO object
    def delete(io)
      h = @fds[io.fileno]
      return nil if h.nil?
      k = h[:kevent]
      ev_set(k, k[:ident], k[:filter], EV_DELETE, k[:fflags], 0, nil)
      kevent(@kqfd, k, 1, nil, 0, nil)
      @fds.delete(io.fileno)
      return io
    end

    def close
      IO.for_fd(@kqfd).close
    end

  end
end
