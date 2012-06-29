#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'galois_server'

GaloisServer.start({:Port  => 8123})