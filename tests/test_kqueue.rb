require 'lib/ktools'
require 'bacon'

describe "the kqueue interface" do

  it "should return a valid kqueue file descriptor" do
    @kqfd = Kqueue::kqueue
    @kqfd.class.should.equal Fixnum
    @kqfd.should.be > 0
  end

  it "should use the raw C API to set an event for file watching, and retrieve the event when it occurs" do
    file = Tempfile.new("kqueue-test")
    k = Kqueue::Kevent.new
    k.should.not.be.nil
    Kqueue::ev_set(k, file.fileno, Kqueue::EVFILT_VNODE, Kqueue::EV_ADD | Kqueue::EV_CLEAR, Kqueue::NOTE_WRITE, 0, nil)
    Kqueue::kevent(@kqfd, k, 1, nil, 0, nil)
    File.open(file.path, 'w'){|x| x.puts 'foo'}
    n = Kqueue::Kevent.new
    res = Kqueue::kevent(@kqfd, nil, 0, n, 1, nil)
    res.should.be > -1
    n[:ident].should.equal file.fileno
    n[:filter].should.equal Kqueue::EVFILT_VNODE
    n[:fflags].should.equal Kqueue::NOTE_WRITE
    file.close
  end

  it "should close the kqueue file descriptor" do
    i = IO.for_fd(@kqfd)
    i.should.not.be.closed
    i.close
    i.should.be.closed
  end

  it "should add file events using the ruby API" do
    file = Tempfile.new("kqueue-test")
    kq = Kqueue.new
    kq.add_file(file, :events => [:write, :delete]).should.be.true

    kq.poll.should.be.empty
    File.open(file.path, 'w'){|x| x.puts 'foo'}

    res = kq.poll.first
    res.class.should.equal Hash
    res[:target].class.should.equal Tempfile
    res[:target].fileno.should.equal file.fileno
    res[:type].should.equal :file
    res[:event].should.equal :write

    kq.poll.should.be.empty
    file.delete

    res2 = kq.poll.first
    res2[:target].class.should.equal Tempfile
    res2[:target].fileno.should.equal file.fileno
    res2[:type].should.equal :file
    res2[:event].should.equal :delete

    file.close
    kq.close
  end

  it "should add events for socket-style descriptors, then delete them, using the Ruby API" do
    r, w = IO.pipe
    kq = Kqueue.new
    kq.add_socket(r, :events => [:read]).should.be.true

    kq.poll.should.be.empty
    w.write "foo"

    res = kq.poll.first
    res[:target].class.should.equal IO
    res[:target].fileno.should.equal r.fileno
    res[:type].should.equal :socket
    res[:event].should.equal :read

    kq.poll.should.be.empty
    kq.delete(r)
    w.write "foo"
    kq.poll.should.be.empty

    [r,w,kq].each{|i| i.close}
  end

end
