require 'lib/ktools'
require 'bacon'

include Kernel::Kqueue

describe "the kqueue interface" do

  it "should return a valid kqueue file descriptor" do
    @kqfd = kqueue
    @kqfd.class.should.equal Fixnum
    @kqfd.should.be > 0
  end

  it "should set an event for file watching, and retrieve the event when it occurs" do
    file = Tempfile.new("kqueue-test")
    k = Kevent.new
    k.should.not.be.nil
    ev_set(k, file.fileno, EVFILT_VNODE, EV_ADD | EV_ONESHOT, NOTE_DELETE | NOTE_RENAME | NOTE_WRITE, 0, nil)
    kevent(@kqfd, k, 1, nil, 0, nil)
    File.open(file.path, 'w'){|x| x.puts 'foo'}
    n = Kevent.new
    res = kevent(@kqfd, nil, 0, n, 1, nil)
    res.should.be > -1
    n[:ident].should.equal file.fileno
    n[:filter].should.equal EVFILT_VNODE
    n[:fflags].should.equal NOTE_WRITE
    file.close
  end

  it "should close the kqueue file descriptor" do
    i = IO.for_fd(@kqfd)
    i.should.not.be.closed
    i.close
    i.should.be.closed
  end

end
