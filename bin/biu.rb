#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

ALWAYS_SUCCESS_HASH = "0x0000000000000000000000000000000000000000000000000000000000000001".freeze

def get_always_success_lock_hash
  always_success_lock = {
    code_hash: ALWAYS_SUCCESS_HASH,
    args: []
  }
  CKB::Utils.json_script_to_type_hash(always_success_lock)
end

def get_always_success_cellbases(api, from, to)
  lock_hash = get_always_success_lock_hash
  api.get_cells_by_lock_hash(lock_hash, from, to).select {|c| c[:capacity] == "5000000000000" }
end

def spend_always_success_cell(api, cell)
  puts "spending: #{cell}"

  outnum = 10
  cap = (cell[:capacity].to_i - 100000000) / outnum

  inputs = [
    {
      previous_output: cell[:out_point],
      args: [],
      valid_since: "0"
    }
  ]

  outputs = []
  outnum.times do |i|
    outputs << {
      capacity: cap.to_s,
      data: CKB::Utils.bin_to_hex("LovePeace@#{i}"),
      lock: {
        code_hash: "0x0000000000000000000000000000000000000000000000000000000000000000", # no one can unlock
        args: []
      }
    }
  end

  tx = CKB::Transaction.new(
    version: 0,
    deps: [api.system_script_out_point],
    inputs: inputs,
    outputs: outputs
  )
  # no need to tx.sign
  api.send_transaction(tx.to_h)
end

def explode_always_success_cell(api, cell, factor)
  puts "spending: #{cell}"

  inputs = [
    {
      previous_output: cell[:out_point],
      args: [],
      since: "0"
    }
  ]

  cap = (cell[:capacity].to_i / factor).to_s
  outputs = []
  factor.times do |i|
    outputs << {
      capacity: cap,
      data: CKB::Utils.bin_to_hex("jan#{i}"),
      lock: {
        code_hash: ALWAYS_SUCCESS_HASH,
        args: []
      }
    }
  end

  tx = CKB::Transaction.new(
    version: 0,
    deps: [api.system_script_out_point],
    inputs: inputs,
    outputs: outputs
  )
  # no need to tx.sign
  api.send_transaction(tx.to_h)
end

def biubiubiu_jan_cells(api, from, to)
  lock_hash = get_always_success_lock_hash
  cells = api.get_cells_by_lock_hash(lock_hash, from, to).select {|c| c[:capacity].to_i < 100000000000 }

  txs = []
  cells.each do |cell|
    inputs = [
      {
        previous_output: cell[:out_point],
        args: [],
        since: "0"
      }
    ]
    outputs = [
      {
        capacity: cell[:capacity].to_s,
        data: CKB::Utils.bin_to_hex(""),
        lock: {
          code_hash: ALWAYS_SUCCESS_HASH,
          args: []
        }
      }
    ]

    tx = CKB::Transaction.new(
      version: 0,
      deps: [api.system_script_out_point],
      inputs: inputs,
      outputs: outputs
    )
    txs.push tx
  end

  txids = []
  puts "sending #{txs.size} transactions ..."
  txs.each_with_index do |tx, i|
    puts "sending tx #{i}/#{txs.size} ..."
    begin
      txids << api.send_transaction(tx.to_h)
    rescue
      p $!
    end
  end
  puts "all transactions sent!"
  txids
end

def explode(api, from, to)
  txs = []
  cells = get_always_success_cellbases(api, from, to)
  30.times do
    tip = api.get_tip_header
    puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"

    begin
      cell = cells.sample
      cells.delete(cell)
      txs << explode_always_success_cell(api, cell, 600)
    rescue
      puts $!.backtrace
      p $!
    end

    sleep 1
  end
  p txs
end

def biubiu(api, from, to)
  txs = []
  tip = api.get_tip_header
  puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"

  begin
    txs = biubiubiu_jan_cells(api, from, to).sample(10)
  rescue
    p $!
  end
  p txs
end


api = CKB::API.new
#key = CKB::Key.new("0x000000000000000000000000000000000000000000000000000000000000ffff")
#wallet = CKB::Wallet.new(api, key)

if ARGV[0] == 'explode'
  explode(api, ARGV[1], ARGV[2])
elsif ARGV[0] == 'biubiu'
  biubiu(api, ARGV[1], ARGV[2])
end

#loop do
#  txs.each do |tx|
#    puts "\n[#{Time.now}] Check tx status ... #{tx}"
#    p api.send(:rpc_request, 'get_pool_transaction', params: [tx])
#    p api.get_transaction(tx)
#  end
#
#  sleep 1
#end
