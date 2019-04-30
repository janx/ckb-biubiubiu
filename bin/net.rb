#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

api = CKB::API.new

local = api.local_node_info
puts "[Local]"
puts "#{local[:node_id]} #{local[:addresses][0][:address]}"

peers = api.send(:rpc_request, 'get_peers')
puts "\n[Peers] #{peers.size}"
peers.each_with_index do |peer, i|
  puts "(#{i}) #{peer[:node_id]} #{peer[:addresses][0][:address]}:#{peer[:addresses][0][:score]}"
end

tip = api.get_tip_header
puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"
p api.send(:rpc_request, :tx_pool_info)

#p api.send(:rpc_request, 'get_pool_transaction')

