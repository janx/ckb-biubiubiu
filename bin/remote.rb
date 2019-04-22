#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

raise "you must specify at least 1 argument!" unless ARGV.size > 0

local = CKB::API.new
peers = local.send(:rpc_request, 'get_peers')

remotes = []
peers.sample(5).each_with_index do |peer, i|
  addr = peer[:addresses][0][:address]
  segs = addr.split('/')
  rpc_endpoint = "http://#{segs[2]}:#{segs[4].to_i+10}"
  puts "(#{i}) #{addr}:#{peer[:addresses][0][:score]} #{rpc_endpoint} #{peer[:node_id]}"
  remotes << CKB::API.new(host: rpc_endpoint)
end

results = []
remotes.each do |api|
  result = api.send(:rpc_request, ARGV[0], params: ARGV[1..-1])
  p result
  results << result
end
