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

def get_lock_hash(api, key)
  CKB::Utils.json_script_to_type_hash(
    CKB::Utils.generate_lock(
      key.address.parse(key.address.generate),
      api.system_script_cell_hash
    )
  )
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

def explode_vanilla_cell(api, cell, factor)
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

def explode_secp_cell(api, key, cell, factor)
  addr = key.address.generate
  puts "spending cell #{cell} to addr: #{addr}"

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
      data: "0x",
      lock: CKB::Utils.generate_lock(
        key.address.parse(addr),
        api.system_script_cell_hash
      )
    }
  end

  tx = CKB::Transaction.new(
    deps: [api.system_script_out_point],
    inputs: inputs,
    outputs: outputs
  )
  # no need to tx.sign
  api.send_transaction(tx.to_h)
end

def biubiu_vanilla_cells(api, from, to)
  lock_hash = get_always_success_lock_hash
  cells = api.get_cells_by_lock_hash(lock_hash, from, to).select {|c| c[:capacity].to_i < 10000000000 }

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

def biubiu_secp_cells(api, key1, key2, from, to)
  addr1 = key1.address.generate
  addr2 = key2.address.generate
  cells = api.get_cells_by_lock_hash(get_lock_hash(api, key1), from, to)

  txs = []
  while !cells.empty?
    cell1, cell2 = cells.sample(2)
    cells.delete(cell1)
    cells.delete(cell2)
    next if cell1.nil? || cell2.nil?

    inputs = [
      {
        previous_output: cell1[:out_point],
        args: [],
        since: "0"
      },
      {
        previous_output: cell2[:out_point],
        args: [],
        since: "0"
      }
    ]

    cap = cell1[:capacity].to_i + cell2[:capacity].to_i
    fee = 50000
    r = [[rand, 0.35].max, 0.65].min
    cap1 = (cap * r).floor
    cap2 = cap - cap1 - fee
    outputs = [
      { # spending to key2
        capacity: cap1.to_s,
        data: "0x",
        lock: CKB::Utils.generate_lock(
          key2.address.parse(addr2),
          api.system_script_cell_hash
        )
      },
      { # charge back to key1
        capacity: cap2.to_s,
        data: "0x",
        lock: CKB::Utils.generate_lock(
          key1.address.parse(addr1),
          api.system_script_cell_hash
        )
      }
    ]

    _tx = CKB::Transaction.new(
      version: 0,
      deps: [api.system_script_out_point],
      inputs: inputs,
      outputs: outputs
    )
    txs.push _tx.sign(key1)
  end

  txids = []
  puts "sending #{txs.size} transactions from #{addr1} to #{addr2} ..."
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

def explode_vanilla(api, from, to)
  txs = []
  cells = get_always_success_cellbases(api, from, to)
  30.times do
    tip = api.get_tip_header
    puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"

    begin
      cell = cells.sample
      cells.delete(cell)
      txs << explode_vanilla_cell(api, cell, 600)
    rescue
      puts $!.backtrace
      p $!
    end

    sleep 1
  end
  p txs
end

def biubiu_vanilla(api, from, to)
  txs = []
  tip = api.get_tip_header
  puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"

  begin
    txs = biubiu_vanilla_cells(api, from, to).sample(10)
  rescue
    p $!
  end
  p txs
end

def explode_secp(api, key, from, to)
  txs = []
  cells = get_always_success_cellbases(api, from, to)
  30.times do
    tip = api.get_tip_header
    puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"

    begin
      cell = cells.sample
      cells.delete(cell)
      txs << explode_secp_cell(api, key, cell, 400)
    rescue
      puts $!.backtrace
      p $!
    end

    sleep 1
  end
  p txs
end

def biubiu_secp(api, key1, key2, from, to)
  txs = []
  tip = api.get_tip_header
  puts "\nBlock##{tip[:number]} #{tip[:hash]} #{Time.at(tip[:timestamp].to_i/1000.0)}"

  begin
    txs = biubiu_secp_cells(api, key1, key2, from, to).sample(10)
  rescue
    p $!
  end
  p txs
end

api = CKB::API.new
key1 = CKB::Key.new("0x1eacee209907437318085d33295fcc721a383f17d4580c76ffc3b62104a2d9b0")
key2 = CKB::Key.new("0xd51fc5a0d6c1aa5a71af04584e413fdba77185069b3980e5ecf361bd05950fcc")
#wallet = CKB::Wallet.new(api, key)

if ARGV[0] == 'explode_vanilla'
  explode_vanilla(api, ARGV[1], ARGV[2])
elsif ARGV[0] == 'biubiu_vanilla'
  biubiu_vanilla(api, ARGV[1], ARGV[2])
elsif ARGV[0] == 'explode_secp'
  explode_secp(api, key1, ARGV[1], ARGV[2])
elsif ARGV[0] == 'biubiu_secp'
  biubiu_secp(api, key1, key2, ARGV[1], ARGV[2])
elsif ARGV[0] == 'generate_key'
  p CKB::Key.random_private_key
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
