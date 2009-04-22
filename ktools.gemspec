Gem::Specification.new do |s|
  s.name = "ktools"
  s.version = "0.0.2"
  s.date = "2009-04-22"
  s.authors = ["Jake Douglas"]
  s.email = "jakecdouglas@gmail.com"
  s.rubyforge_project = "ktools"
  s.has_rdoc = true
  s.add_dependency('ffi')
  s.add_dependency('bacon')
  s.summary = "Bringing common kernel APIs into Ruby using FFI"
  s.homepage = "http://www.github.com/yakischloba/ktools"
  s.description = "Bringing common kernel APIs into Ruby using FFI"
  s.extensions = ["Rakefile"]
  s.files =
    ["ktools.gemspec",
    "README",
    "Rakefile",
    "lib/ktools.rb",
    "lib/ktools/ktools.rb",
    "lib/ktools/epoll.rb",
    "lib/ktools/kqueue.rb",
    "ext/ktools.c",
    "ext/ktools.h",
    "ext/epoll.c",
    "ext/epoll.h",
    "ext/kqueue.c",
    "ext/kqueue.h",
    "tests/test_epoll.rb",
    "tests/test_kqueue.rb"]
end
