#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

api = CKB::API.new

local = api.local_node_info
puts "[Local]"
puts "#{local.node_id} #{local.addresses[0].address}"

peers = api.get_peers
puts "\n[Peers] #{peers.size}"
peers.each_with_index do |peer, i|
  puts "(#{i}) #{peer.node_id} #{peer.addresses[0].address}:#{peer.addresses[0].score}"
end

puts "\n"
p api.get_current_epoch.to_h

tip = api.get_tip_header
blk = api.get_block tip.hash
pool = api.tx_pool_info
puts "\nBlock##{tip.number} #{tip.hash} #{Time.at(tip.timestamp.to_i/1000.0)}"
puts "Transactions pending:#{pool.pending} proposed:#{pool.proposed} committed:#{blk.transactions.size} orphan:#{pool.orphan}"

#p api.send(:rpc_request, 'get_pool_transaction')

