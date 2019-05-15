#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

local = CKB::API.new

from = ARGV[0].to_i
to = ARGV[1].to_i
(from...to).each do |i|
  hash = local.get_block_hash i
  blk = local.get_block hash
  if blk.transactions.size > 1000
    puts hash
    puts blk.header.number
    break
  end
end
