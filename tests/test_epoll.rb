require 'lib/ktools'
require 'bacon'

include Kernel::Epoll

describe "the epoll interface" do

  it "should return a valid epoll file descriptor" do
    @epfd = epoll_create(10)
    @epfd.class.should.equal Fixnum
    @epfd.should.be > 0
  end

  it "should set an event for readable status of a descriptor, and retrieve the event when it occurs" do
    r, w = IO.pipe
    ev = Epoll_event.new
    ev[:events] = EPOLLIN
    ev[:data] = Epoll_data.new
    ev[:data][:fd] = r.fileno
    ev[:data][:u32] = 12345
    epoll_ctl(@epfd, EPOLL_CTL_ADD, r.fileno, ev).should.equal 0
    rev = Epoll_event.new
    epoll_wait(@epfd, rev, 1, 50).should.equal 0
    w.write "foo"
    epoll_wait(@epfd, rev, 1, 50).should.equal 1
    rev[:events].should.equal EPOLLIN
    rev[:data][:fd].should.equal r.fileno
    rev[:data][:u32].should.equal 12345
    w.close
    r.close
    w.should.be.closed
    r.should.be.closed
  end

  it "should close the epoll file descriptor" do
    i = IO.for_fd(@epfd)
    i.should.not.be.closed
    i.close
    i.should.be.closed
  end

end
