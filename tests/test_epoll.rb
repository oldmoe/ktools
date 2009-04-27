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
    ev[:data][:fd] = r.fileno
    Epoll::epoll_ctl(@epfd, Epoll::EPOLL_CTL_ADD, r.fileno, ev).should.equal 0
    rev = Epoll::Epoll_event.new
    Epoll::epoll_wait(@epfd, rev, 1, 50).should.equal 0
    w.write "foo"
    Epoll::epoll_wait(@epfd, rev, 1, 50).should.equal 1
    rev[:events].should.equal Epoll::EPOLLIN
    rev[:data][:fd].should.equal r.fileno
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

    res[:events].should.include :read
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
  
  it "should provide aggregated events on a target" do
    r, w = IO.pipe
    ep = Epoll.new

    ep.add(:socket, r, :events => [:read, :hangup]).should.be.true
    ep.poll.should.be.empty

    w.write 'foo'
    w.close

    res = ep.poll.first
    res[:type].should.equal :socket
    res[:target].fileno.should.equal r.fileno
    res[:events].should.include :read
    res[:events].should.include :hangup

    [r, ep].each{|i| i.close}
  end

  it "should provide multiple events in one poll" do
    ep = Epoll.new

    r1, w1 = IO.pipe
    r2, w2 = IO.pipe
    ep.add(:socket, r1, :events => [:read]).should.be.true
    ep.add(:socket, r2, :events => [:read]).should.be.true

    ep.poll.should.be.empty

    w1.write 'foo'
    w2.write 'bar'

    res = ep.poll
    res.size.should.equal 2

    # for some reason we get these in reverse order. figure out why someday.
    res.first[:target].fileno.should.equal r2.fileno
    res.first[:type].should.equal :socket
    res.first[:events].size.should.equal 1
    res.first[:events].should.include :read

    res.last[:target].fileno.should.equal r1.fileno
    res.last[:type].should.equal :socket
    res.last[:events].size.should.equal 1
    res.last[:events].should.include :read

    [r1, w1, r2, w2, ep].each{|i| i.close}
  end

end
