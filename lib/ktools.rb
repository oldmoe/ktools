$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'ffi'
require 'ffi/tools/const_generator'
require 'ktools/ktools'
require 'ktools/kqueue' if Kernel.have_kqueue?
require 'ktools/epoll' if Kernel.have_epoll?
