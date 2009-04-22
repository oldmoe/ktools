describe "the epoll interface" do

  it "should return a valid epoll file descriptor" do
    @epfd = Epoll::epoll_create(10)
    @epfd.class.should.equal Fixnum
    @epfd.should.be > 0
  end

  it "should set an event for readable status of a descriptor, and retrieve the event when it occurs" do
    r, w = IO.pipe
    ev = Epoll::Epoll_event.new
    ev[:events] = Epoll::EPOLLIN
    ev[:data] = Epoll::Epoll_data.new
    ev[:data][:fd] = r.fileno
    ev[:data][:u32] = 12345
    Epoll::epoll_ctl(@epfd, Epoll::EPOLL_CTL_ADD, r.fileno, ev).should.equal 0
    rev = Epoll::Epoll_event.new
    Epoll::epoll_wait(@epfd, rev, 1, 50).should.equal 0
    w.write "foo"
    Epoll::epoll_wait(@epfd, rev, 1, 50).should.equal 1
    rev[:events].should.equal Epoll::EPOLLIN
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

  it "should add socket events and retrieve them using the Ruby API" do
    r, w = IO.pipe
    ep = Epoll.new

    ep.add(:socket, r, :events => [:read]).should.be.true
    ep.poll.should.be.empty

    w.write 'foo'
    res = ep.poll.first

    res[:event].should.equal :read
    res[:target].fileno.should.equal r.fileno
    res[:type].should.equal :socket

    [r,w,ep].each{|i| i.close}
  end

  it "should delete events using the Ruby API" do
    r, w = IO.pipe
    ep = Epoll.new

    ep.add(:socket, r, :events => [:read]).should.be.true
    ep.poll.should.be.empty

    w.write 'foo'
    ep.delete(:socket, r).should.be.true

    ep.poll.should.be.empty

    [r,w,ep].each{|i| i.close}
  end

end
