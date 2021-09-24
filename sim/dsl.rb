require 'date'
require 'dotenv/load'
require_relative 'reflow_os_client.rb'

#dsl for generating value flow simulation 
# this simulation first generate all the necessary operations in a setup phase and a timetable
# then executes the setup phase and when it's done the timetable on entry at a time using graphql requests with delays in between

def simulation(label, date_start = Date.today, date_end = Date.today + 365)
  puts "#{date_start} -> #{date_end}"
  ts = date_start.to_time.to_datetime
  $context = {:date => ts} #clean the context for every call
  $client = ReflowOSClient.new

  $planned_events = [] #array of days, each do contains array of event keys to process on that day
  $nr_of_days = (date_end - date_start).to_i
  $nr_of_days.times do  |index|
    $planned_events[index] = [] #no events planned
  end
  yield #setup / generate agents, resources and schedule events

  # show internal state after setup
  puts "--- SETUP ---"
  print_state  
  puts "--- RUN SIMULATION ---"
  $nr_of_days.times do  |index|
    day = date_start + index #no events planned
    $planned_events[index].each do |event_key|
      puts "#{day}: processing event: #{event_key}"
      #execute the process
      ts = day.to_time.to_datetime
      $context = {:date => ts} #clean the context for every call
      $processes[event_key].call
      sleep 0.1 #delay not to go to fast
    end
  end
  puts "--- AFTER ---"
  print_state
end

def print_state
  puts "AGENTS"
  $agents.keys.each do |key|
    puts "#{key}: #{$agents[key]} "
  end
  puts "LOTS"
  $lots.keys.each do |key|
    puts "#{key}: #{$lots[key][:items].count} "
  end
  puts "POOLS"
  $pools.keys.each do |key|
    puts "#{key}: #{$pools[key][:items].count} (#{$pools[key][:agent_key]})"
  end
  puts "INVENTORIES"
  $inventories.keys.each do |key|
    puts "#{key}: #{$inventories[key][:items].count} (#{$inventories[key][:agent_key]})"
  end
end

# setup an agent
$agents = Hash.new
def agent(key, label)
  $agents[key] = {:label => label}
  $context[:agent_key] = key #used as context for block 
  yield if block_given?
end

# check credentials and login as an agent,
# using credentials from enviroment
def authenticate(email_key, pw_key)
  Dotenv.require_keys(email_key, pw_key)  
  key = $context[:agent_key]
  token = $client.login(ENV[email_key],ENV[pw_key])
  $agents[key][:token] = token # save for reuse
  agent_id = $client.me(token)
  $agents[key][:agent_id] = agent_id #TODO use the myagent call instead
end

def location(location_key)
  Dotenv.require_keys(location_key)  
  key = $context[:agent_key]
  location = ENV[location_key]
  $agents[key][:location] = location # save for reuse
end

# setup a resource type e.g. gown, 
# expects a block that can be used to generate a resource instance, a hash that contains two keys
# :rid and :description
$resources = Hash.new 
def resource(key, label, &proc)
  $resources[key] = {:label => label, :generator => proc}
end

# a collection of resources that can be used for transfers
# type refers to an id of a resource that has been defined as a resource 
# amount for lot is always specified by the event
# items will be added / removed inside events, not at definition time
$lots = Hash.new
def lot(key, label, resource_key)
  raise "resource not found: #{resource_key}" if not $resources.key? resource_key 
  $lots[key] = {:label => label, :resource_key => resource_key, :items => []}
end

# a collection of resources that we want to keep track of in the simulation 
# (belongs to an agent)
$pools = Hash.new
def pool(key, label, resource_key, amount = 0)
  raise "resource not found: #{type}" if not $resources.key? resource_key 
  items = []
  # generate the initial items 
  if(amount > 0)
      amount.times do 
        item = $resources[resource_key][:generator].call
        resource_label = $resources[resource_key][:label]

        # first time should produce
        agent = $agents[$context[:agent_key]]
        date = $context[:date]

        #create the item in reflow os and save the id for future reference
        # puts "seeding pool item as #{$context[:agent_key]}"
        item[:id] = $client.produce_one(
          agent[:token], 
          agent[:agent_id], 
          resource_label, 
          item[:tracking_id], 
          agent[:location],
          "seed pool for #{$context[:agent_key]} - #{$context[:date]}",
          item[:description],
          date.iso8601)
        item[:created_by] = $context[:agent_key]
        item[:created_at_day] = $context[:date].iso8601
        items << item
      end
  end
  $pools[key] = {:label => label, :resource_key => resource_key, :items => items, :agent_key => $context[:agent_key] }
  
  end

# a collection of resources that we want to keep track of in the simulation AND in reflow os 
$inventories = Hash.new
def inventory(key, label, resource_key, amount = 0)
  raise "resource not found: #{type}" if not $resources.key? resource_key 

  resource_label = $resources[resource_key][:label]
  # first time should produce
  agent = $agents[$context[:agent_key]]
  date = $context[:date]

  stock_id = $client.produce_empty_container(
          agent[:token], 
          agent[:agent_id], 
          "#{resource_label} Stock", 
          agent[:location],
          "seed event for stock resource #{$context[:agent_key]} - #{$context[:date]}",
          "#{resource_label} Stock",
          date.iso8601)

  items = []
 
  # generate the initial items 
  if(amount > 0)
      amount.times do 
        item = $resources[resource_key][:generator].call
        
        # create the item in reflow os and save the id for future reference
        # and place them in stock
        item[:id] = $client.produce_one(
          agent[:token], 
          agent[:agent_id], 
          resource_label, 
          item[:tracking_id], 
          agent[:location],
          "seed pool for #{$context[:agent_key]} - #{$context[:date]}",
          item[:description],
          date.iso8601,
          stock_id)
 
        item[:created_by] = $context[:agent_key]
        item[:created_at_day] = $context[:date].iso8601
        
        # puts item
        items << item
      end
  end
  
  $inventories[key] = {:label => label, :resource_key => resource_key, :items => items, :agent_key => $context[:agent_key], :stock_id => stock_id }
end

$events = Hash.new
def event(key, label)
  $context[:event_key] = key 
  $context[:event_label] = label 
  yield
end

# every specifies frequency in days, amount is an amount to generate, 
# on specifes the name of an event that triggers the event, 
# with_delay delays the start by a number of days
# hash arguments; cron, on_event, with_delay
def schedule(args) 
  event_key = $context[:event_key]
  if(args[:cron] != nil)
    $nr_of_days.times do |day_nr|
      if (day_nr % args[:cron] == 0)
        $planned_events[day_nr] << event_key 
      end
    end
  end

  if(args[:on_event] != nil)
    trigger_event_key = args[:on_event] 
    delay = 0
    delay = args[:with_delay] if(args[:with_delay] != nil)
    $nr_of_days.times do |day_nr|
      if ($planned_events[day_nr].include? trigger_event_key)
        if(day_nr + delay < $planned_events.count)
          $planned_events[day_nr + delay] << event_key
        end
      end
    end
  end

end

$processes = Hash.new 
def process(&proc)
  event_key = $context[:event_key]
  $processes[event_key] = proc #save the process to execute when the event is scheduled 
end

def role(agent, role)
  puts "role: #{$cur_id} #{agent}: #{role}"
end

def flow(ids)
  puts ids.join(" -> ") 
end

#set the amount for the current context for a verb
def with_amount(amount)
  $context[:process_amount] = amount
end

#set the current agent
def as_performer(agent)
  $context[:process_performer] = agent 
end

#convenience function to return the current number of items in the resource
#can be a single resource, a lot, pool or inventory
def current_amount(resource_key)
  return 1 if $resources.key? resource_key
  return $lots[resource_key][:items].count if $lots.key? resource_key
  return $pools[resource_key][:items].count if $pools.key? resource_key
  return $inventories[resource_key][:items].count if $inventories.key? resource_key
  raise "Can't find resource: #{resource_key}"
end

# place amount items from the specified pool in the context batch
def pool_take(pool_key, amount = nil)
  max = current_amount(pool_key)
  amount = max  if (amount == nil or amount > max)

  items = $pools[pool_key][:items].take(amount)
  $pools[pool_key][:items] = $pools[pool_key][:items].drop(amount)
  $context[:batch] = items
end

# remove and return amount items from the specified inventory
def inventory_take(inventory_key, amount = nil)
  max = current_amount(inventory_key)
  amount = max  if (amount == nil or amount > max)

  items = $inventories[inventory_key][:items].take(amount)
  $inventories[inventory_key][:items] = $inventories[inventory_key][:items].drop(amount)
  $context[:batch] = items
end

def lot_take(lot_key)
  items = $lots[lot_key][:items]
  $lots[lot_key][:items] = [] 
  $context[:batch] = items
end

# take resources out of a lot, and recreate effectively unpacking
def unpack_lot(lot_key)
  resource_key = $lots[lot_key][:resource_key]
  resource_label = $resources[resource_key][:label]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]

  lot_take(lot_key)  # places them in batch
  packed_items = $context[:batch] 
  unpacked_items = []

  #recreate as own
  packed_items.each do |item| 
    item[:id] = $client.produce_one(
      agent[:token], 
      agent[:agent_id], 
      resource_label, 
      item[:tracking_id], 
      agent[:location],
      "unpacked by #{$context[:process_performer]} - #{$context[:date]}",
      item[:description],
      date.iso8601)
    item[:created_by] = $context[:process_performer]
    item[:created_at_day] = $context[:date].iso8601
    unpacked_items << item 
  end
  $context[:batch] = unpacked_items
end

# add the items in the context batch to the pool
def pool_put(pool_key)
  items = $context[:batch]
  $pools[pool_key][:items].concat items
end

# add the items to the inventory
def inventory_put(inventory_key)
  items = $context[:batch]
  $inventories[inventory_key][:items].concat items
end

#replace the lot items
def lot_put(lot_key)
  items = $context[:batch]
  $lots[lot_key][:items] = items
end

# all actions will perform graphql calls
def use_batch(note)
  items = $context[:batch]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]

  puts "graphql USE by #{performer} on #{items.count} items" 
  
  items.each do |item|
    event_id = $client.use_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        note,
        date.iso8601)
    puts "Created Reflow OS Use event: #{event_id}"
  end
end

def modify_batch(note)
  items = $context[:batch]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]

  puts "graphql MODIFY by #{performer} on #{items.count} items" 
  
  items.each do |item|
    event_id = $client.modify_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        note,
        date.iso8601)
    puts "Created Reflow OS Modify event: #{event_id}"
  end
end

#removes 1 - fraction items and places them in batch_failed
def pass_batch(fraction)
  items = $context[:batch]
  amount_passed = (items.count * fraction).to_i # between zero and three items fail the inspection
  passed = items.take(amount_passed)
  failed = items.drop(amount_passed)
  $context[:batch] = passed
  $context[:batch_failed] = failed # in case we want to do something with this
end

# perform a consume verb, if a fraction is specified operate on part of the batch, 
# default operate on everything
def consume_batch
  items = $context[:batch]
  performer = $context[:process_performer]
  puts "graphql CONSUME #{items.count} items by #{performer}"
  
  agent = $agents[performer]
  date = $context[:date]

  items.each do |item|
    event_id = $client.consume_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        "consume for #{$context[:process_performer]}",
        date.iso8601)

    puts "Created Reflow OS Consume event: #{event_id}"
  end
end

# consume a single lot resource
def action_consume_lot(lot_key)
  performer = $context[:process_performer]
  date = $context[:date]
  agent = $agents[performer]
  resource_key = $lots[lot_key][:resource_key]
  
  puts "graphql CONSUME #{resource_key} by #{performer}" 
  item = $lots[lot_key]
  event_id = $client.consume_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        "consume lot by #{$context[:process_performer]}",
        date.iso8601)

  puts "Created Reflow OS Consume lot event: #{event_id}"
end

def produce_lot(lot_key)
  manifest_items = $context[:batch]
  performer = $context[:process_performer] 
  puts "graphql PRODUCE #{lot_key} with #{$lots[lot_key][:items].count} items by #{performer}"
 
  agent = $agents[performer]
  date = $context[:date]
  resource_key = $lots[lot_key][:resource_key]
  resource_label = $resources[resource_key][:label]
 
  #create a lot resource in reflow os, put in the list of tracking id's as the manifest note  
  manifest = manifest_items.map{|item|item[:tracking_id]}.join(",")
  puts "manifest: #{manifest}"
  lot_id = $client.produce_empty_container(
          agent[:token], 
          agent[:agent_id], 
          "#{resource_label} Lot", 
          agent[:location],
          "#{resource_label} Lot",
          "Manifest: #{manifest}",
          date.iso8601) #returns lot id

  $lots[lot_key][:id] = lot_id
  puts "Created Reflow OS Lot event: #{lot_id}"
end

def action_produce_batch(items)
  performer = $context[:process_performer] 
  puts "graphql PRODUCE #{items.count} items by #{performer}"
end

def transfer_lot(lot_key, provider, receiver)
 
  provider = $agents[provider]
  receiver = $agents[receiver]
  date = $context[:date]

  resource_key = $lots[lot_key][:resource_key]
  resource_label = $resources[resource_key][:label]
  lot_id = $lots[lot_key][:id]
  location_id =  receiver[:location]

  puts "graphql TRANSFER of #{resource_key} Lot from #{provider[:label]} to #{receiver[:label]}"
 
  #transfer from provider to receiver (by provider)
  event_id = $client.transfer_lot(
    provider[:token],
    provider[:agent_id],
    receiver[:agent_id],
    lot_id,
    "#{resource_label} Lot Transfer",
    date.iso8601,
    location_id) 

  #also do a move from provider to receiver (by provider)
#   event_id = $client.move_lot(
#     provider[:token],
#     provider[:agent_id],
#     receiver[:agent_id],
#     lot_id,
#     "#{resource_label} Lot Transfer",
#     date.iso8601,
#     location_id) 

    puts "Created Reflow OS TRANSFER event: #{event_id}"
end

# pack a batch into the lot specified by lot_key
# side effect: produces a new resource and assigns it to the lot key
def pack_lot(lot_key)
      consume_batch 
      lot_put lot_key
      produce_lot lot_key 
end
