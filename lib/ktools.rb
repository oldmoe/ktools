require 'rubygems'
require 'ffi'
require 'ffi/tools/const_generator'
require 'lib/ktools/ktools'
require 'lib/ktools/kqueue' if Kernel.have_kqueue?
require 'lib/ktools/epoll' if Kernel.have_epoll?