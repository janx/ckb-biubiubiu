#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'ckb'

def get_privkey(name)
  File.read(name).strip
end

def miner_key
  @_miner_key ||= CKB::Key.new(get_privkey("key"))
end

def key1
  @_key1 ||= CKB::Key.new(get_privkey("key1"))
end

def key2
  @_key2 ||= CKB::Key.new(get_privkey("key2"))
end

def get_secp_lock(api, key)
  CKB::Types::Script.generate_lock(
    key.address.blake160,
    api.system_script_cell_hash
  )
end

def get_cellbases(api, from, to)
  miner_lock = get_secp_lock(api, miner_key)
  api.get_cells_by_lock_hash(miner_lock.to_hash, from, to).select {|c| c.out_point.cell.index == 0 }
end

def explode_secp_cell(api, key, cell, factor)
  addr = key.address.generate
  puts "explode cellbase #{cell} to #{factor} cells at address #{addr}"

  inputs = [
    CKB::Types::Input.new(
      previous_output: cell.out_point,
      args: [],
      since: "0"
    )
  ]

  cap = cell.capacity.to_i / factor
  outputs = []
  factor.times do |i|
    outputs.push CKB::Types::Output.new(
      capacity: cap,
      lock: CKB::Types::Script.generate_lock(
        key.address.parse(addr),
        api.system_script_cell_hash
      )
    )
  end

  tx = CKB::Types::Transaction.new(
    version: "0",
    deps: [api.system_script_out_point],
    inputs: inputs,
    outputs: outputs
  )
  tx_hash = api.compute_transaction_hash(tx)
  api.send_transaction tx.sign(miner_key, tx_hash)
end

def biubiu_secp_cells(api, key1, key2, from, to)
  addr1 = key1.address.generate
  addr2 = key2.address.generate
  cells = api.get_cells_by_lock_hash(get_secp_lock(api, key1).to_hash, from, to).shuffle

  txs = []
  expected = cells.size / 2
  while !cells.empty?
    cell1, cell2 = cells.sample(2)
    cells.delete(cell1)
    cells.delete(cell2)
    next if cell1.nil? || cell2.nil?

    inputs = [
      CKB::Types::Input.new(
        previous_output: cell1.out_point,
        args: [],
        since: "0"
      ),
      CKB::Types::Input.new(
        previous_output: cell2.out_point,
        args: [],
        since: "0"
      )
    ]

    cap = cell1.capacity.to_i + cell2.capacity.to_i
    fee = 50000
    r = [[rand, 0.35].max, 0.65].min
    cap1 = (cap * r).floor
    cap2 = cap - cap1 - fee
    outputs = [
      # spending to key2
      CKB::Types::Output.new(
        capacity: cap1,
        lock: CKB::Types::Script.generate_lock(
          key2.address.parse(addr2),
          api.system_script_cell_hash
        )
      ),
      # charge back to key1
      CKB::Types::Output.new(
        capacity: cap2,
        lock: CKB::Types::Script.generate_lock(
          key1.address.parse(addr1),
          api.system_script_cell_hash
        )
      )
    ]

    _tx = CKB::Types::Transaction.new(
      version: "0",
      deps: [api.system_script_out_point],
      inputs: inputs,
      outputs: outputs
    )
    _tx_hash = api.compute_transaction_hash(_tx)
    txs.push _tx.sign(key1, _tx_hash)
    puts "#{txs.size}/#{expected} transactions prepared"
  end

  txids = []
  puts "sending #{txs.size} transactions from #{addr1} to #{addr2} ..."
  t1 = Time.now
  txs.each_with_index do |tx, i|
    begin
      tt1 = Time.now.to_f
      txids << api.send_transaction(tx)
      tt2 = Time.now.to_f
      puts "#{i+1}/#{txs.size} sent in #{tt2-tt1}s, begin: #{tt1}, end: #{tt2}"
    rescue
      p $!
    end
  end
  t2 = Time.now

  t3 = Time.now
  puts "all transactions sent in #{t2 - t1} seconds! confirming..."
  txids.each_with_index do |id, i|
    loop do
      _tx = api.get_transaction(id)
      break if _tx.tx_status.status == 'committed'
      sleep 1
    end
    t3 = Time.now if i == 0
    puts "#{i+1}/#{txids.size} transactions committed"
  end
  t4 = Time.now
  puts "all #{txids.size} transactions committed!"
  puts "send: #{txids.size / (t2-t1).to_f}tx/s, used #{t2-t1} seconds"
  puts "commit: #{txids.size / (t4-t3).to_f}tx/s, used #{t4-t3} seconds"
  puts "avg: #{txids.size / (t4-t1).to_f}tx/s, #{t4-t1} seconds"

  first = txids.first
  last = txids.last
  [first] + txids.sample(10) + [last]
end

def explode_secp(api, key, from, to)
  txs = []
  cells = get_cellbases(api, from, to)
  factor = cells.first.capacity.to_i / 10**8 / 125

  90.times do
    tip = api.get_tip_header
    puts "\nBlock##{tip.number} #{tip.hash} #{Time.at(tip.timestamp.to_i/1000.0)}"

    begin
      cell = cells.sample
      cells.delete(cell)
      txs << explode_secp_cell(api, key, cell, factor)
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
  puts "\nBlock##{tip.number} #{tip.hash} #{Time.at(tip.timestamp.to_i/1000.0)}"

  begin
    txs = biubiu_secp_cells(api, key1, key2, from, to)
  rescue
    puts $!.backtrace
    p $!
  end
  p txs
end

def perf(api, from, to)
  a = from
  b = to
  t1 = 0
  (from...to).each do |i|
    blk = api.get_block_by_number i
    if blk.transactions.size > 1
      a = i
      t1 = blk.header.timestamp.to_i / 1000.0
      puts "count begin: ##{a} #{blk.header.hash}"
      break
    end
    puts "skip empty block ##{blk.header.number} #{blk.header.hash}"
  end
  count = 0
  (a...to).each do |i|
    blk = api.get_block_by_number i
    if !blk.nil? && blk.transactions.size > 1
      count += blk.transactions.size
    else
      puts "hit empty block ##{blk.header.number} #{blk.header.hash}"
      b = i-1
      break
    end
  end
  blk = api.get_block_by_number b
  puts "count end: ##{b} #{blk.header.hash}"
  t2 = blk.header.timestamp.to_i / 1000.0
  adjusted_time = (t2 - t1) * (b - a + 1).to_f / (b - a).to_f
  tps = count / adjusted_time
  puts "blocks: #{b-a} txs: #{count}"
  puts "t1: #{t1} t2: #{t2} duration: #{adjusted_time}"
  puts "tps: #{tps} txs/s"
end

api = CKB::API.new
#wallet = CKB::Wallet.new(api, key)

if ARGV[0] == 'explode_secp'
  explode_secp(api, key1, ARGV[1], ARGV[2])
elsif ARGV[0] == 'biubiu_secp'
  biubiu_secp(api, key1, key2, ARGV[1], ARGV[2])
elsif ARGV[0] == 'perf'
  perf(api, ARGV[1].to_i, ARGV[2].to_i)
elsif ARGV[0] == 'generate_key'
  p CKB::Key.random_private_key
end
