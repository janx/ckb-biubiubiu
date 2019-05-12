#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

local = CKB::API.new

#blk_hash = local.get_block_hash "5796"
#blk = local.get_block(blk_hash)
#p blk[:commit_transactions].size
#p blk[:header]
#p blk[:commit_transactions][0]
#p blk[:commit_transactions][1]

p local.rpc.send :rpc_request, ARGV[0], params: ARGV[1..-1]

