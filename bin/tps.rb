#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

local = CKB::API.new

tip = local.get_tip_header
p tip

tt = t = tip[:timestamp].to_i
t0 = t
count = 0
20.times do |i|
  hash = local.get_block_hash("#{tip[:number].to_i - i}")
  blk = local.get_block(hash)
  tt = blk[:header][:timestamp].to_i
  elapse = (t - tt) / 1000.0
  txs = blk[:commit_transactions].size
  count += txs
  puts "time=#{elapse} txs=#{txs} tps=#{txs/elapse}"
  t = tt
end

elapse = (t0 - t) / 1000.0
puts "time=#{elapse} txs=#{count} avg_tps=#{count/elapse}"
