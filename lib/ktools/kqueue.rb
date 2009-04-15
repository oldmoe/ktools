module Kernel
  module Kqueue
    extend FFI::Library

    class Kevent < FFI::Struct
      layout :ident, :uint, 
      :filter, :short, 
      :flags, :ushort, 
      :fflags, :uint, 
      :data, :int, 
      :udata, :pointer
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

    # Had to write a wrapper for EV_SET since its a macro
    attach_function :ev_set, :wrap_evset, [:pointer, :uint, :short, :ushort, :uint, :int, :pointer], :void
    # We wrap kqueue and kevent because we use rb_thread_blocking_region when it's available in MRI
    attach_function :kqueue, :wrap_kqueue, [], :int
    attach_function :kevent, :wrap_kevent, [:int, :pointer, :int, :pointer, :int, :pointer], :int
  end
end