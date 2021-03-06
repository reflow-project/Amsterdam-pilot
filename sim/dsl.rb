require 'date'
require 'dotenv/load'
require 'faker'
require_relative 'reflow_os_client.rb'
# require 'byebug'

$my_cnfig = nil
if(File.file?('.config.yaml'))
  # base data that needs to be present in .config.yaml: 
  #
  # - authentication for each agent
  # - address of the instance (if not local)
  puts "Reading configuration"
  $my_cnfig = YAML.load_file('.config.yaml')
else
  puts "No configuration found"
end

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

  # before yielding, create and authenticate the admin user
  # used for creating units and locations
  if(! $my_cnfig.nil?)
    email = $my_cnfig['a_hospital']['email']
    pw = $my_cnfig['a_hospital']['pw']
    name = $my_cnfig['a_hospital']['name']
  else
    email = Faker::Internet.email
    pw = Faker::Alphanumeric.alphanumeric(number: 10, min_alpha: 3)
    name = Faker::Name.unique.first_name 
    id = $client.make_agent(email,pw,name,"Admin")
    if(id.nil?)
      puts "creating admin failed"
      exit      
    end
  end
  $context[:agent_key] = :a_admin
  $agents[:a_admin] = {:label => "Admin", :email => email, :password => pw}
  authenticate(email,pw)
  
  
  yield #setup / generate units, locations, agents, resources and schedule events

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
    end
  end
  puts "--- AFTER ---"
  print_state
end

def print_state
  puts "UNITS"
  $units.keys.each do |key|
    puts "#{key}: #{$units[key]}"
  end

  puts "AGENTS"
  $agents.keys.each do |key|
    puts "#{key}: #{$agents[key]} "
  end
  puts "CONTAINERS"
  $containers.keys.each do |key|
    puts "#{key}: #{$containers[key][:items].count} "
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
  if(! $my_cnfig.nil?)
    my_key = key.to_s
    email = $my_cnfig[my_key]['email']
    pw = $my_cnfig[my_key]['pw']
    name = $my_cnfig[my_key]['name']
  else
    #create and authenticate the agent
    email = Faker::Internet.email
    pw = Faker::Alphanumeric.alphanumeric(number: 10, min_alpha: 3)
    name = "#{Faker::Name.unique.first_name}#{Faker::Number.number(digits: 4)}"
    id = $client.make_agent(email,pw,name,label)
    puts "created agent: #{id}"
  end
  $agents[key] = {:label => label, :email => email, :password => pw}
  $context[:agent_key] = key #used as context for block 
  authenticate(email, pw)
  yield if block_given?
end

# check credentials and login as an agent,
# using credentials from enviroment
def authenticate(email, pw)
  key = $context[:agent_key]
  token = $client.login(email,pw)
  $agents[key][:token] = token # save for reuse
  agent_id = $client.me(token)
  $agents[key][:agent_id] = agent_id #TODO use the myagent call instead
end

def location(lat,lon,address,name,note)
  key = $context[:agent_key]
  token = $agents[key][:token]
  location = $client.location(token,lat,lon,address,name,note) 
  $agents[key][:location] = location # save for reuse
end

# setup a unit, e.g. om2:one
# created with the admin user by default
$units = Hash.new
def unit(key, label, symbol)
  token = $agents[:a_admin][:token]
  $units[key] = $client.unit(token, label, symbol) 
end

# setup a resource type e.g. gown, 
# expects a block that can be used to generate a resource instance, a hash that contains two keys
# :rid and :description
$resources = Hash.new 
def resource(key, label, unit_key, &proc)
  unit_id = $units[unit_key]
  $resources[key] = {:label => label, :unit => unit_id, :generator => proc}
end

# a collection of resources that can be used for transfers
# type refers to an id of a resource that has been defined as a resource 
# amount for container is always specified by the event
# items will be added / removed inside events, not at definition time
$containers = Hash.new
def container(key, label, resource_key)
  raise "resource not found: #{resource_key}" if not $resources.key? resource_key 
  $containers[key] = {:label => label, :resource_key => resource_key, :items => []}
end

# a collection of resources that we want to keep track of in the simulation 
# (belongs to an agent)
$pools = Hash.new
def pool(key, label, resource_key, amount = 0)
  raise "resource not found: #{type}" if not $resources.key? resource_key 
 
  #create one process that wraps all the produce events
  agent = $agents[$context[:agent_key]]
  date = $context[:date]
  
  process_id = $client.process(
    agent[:token],
    "birth process",
    "seed pool for #{agent[:agent_id]}",
    date.iso8601
  )
  puts "created (pool) process: #{process_id}"

  items = []
  # generate the initial items 
  if(amount > 0)
      amount.times do 
        item = $resources[resource_key][:generator].call
        item[:unit] = $resources[resource_key][:unit]
        resource_label = $resources[resource_key][:label]

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
          date.iso8601,
          item[:unit],
          nil, #no stock id
          process_id
        )

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
  unit_id = $resources[resource_key][:unit]
  # first time should produce
  agent = $agents[$context[:agent_key]]
  date = $context[:date]

  process_id = $client.process(
    agent[:token],
    "birth process",
    "seed inventory for #{agent[:agent_id]}",
    date.iso8601
  )
  puts "created (inventory birth) process: #{process_id}"

  stock_id = $client.produce_empty_container(
          agent[:token], 
          agent[:agent_id], 
          "#{resource_label} Stock", 
          agent[:location],
          "seed event for stock resource #{$context[:agent_key]} - #{$context[:date]}",
          "#{resource_label} Stock",
          date.iso8601,
          unit_id,
          process_id
  )

  items = []
 
  # generate the initial items 
  if(amount > 0)
      amount.times do 
        item = $resources[resource_key][:generator].call
        item[:unit] = $resources[resource_key][:unit]
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
          item[:unit],
          stock_id,
          process_id
        )
 
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
#can be a single resource, a container, pool or inventory
def current_amount(resource_key)
  return 1 if $resources.key? resource_key
  return $containers[resource_key][:items].count if $containers.key? resource_key
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

def container_take(container_key)
  items = $containers[container_key][:items]
  $containers[container_key][:items] = [] 
  $context[:batch] = items
end

# take resources out of a container, and recreate effectively unpacking
def unpack_container(container_key)
  resource_key = $containers[container_key][:resource_key]
  resource_label = $resources[resource_key][:label]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]

  process_id = $client.process(
    agent[:token],
    "unpack process",
    "unpack by #{agent[:label]}",
    date.iso8601
  )
  puts "created (unpack) process: #{process_id}"

  #consume the container (inputOf)
  container_id = $containers[container_key][:id]
  event_id = $client.consume_one(
        agent[:token], 
        agent[:agent_id], 
        container_id, 
        "consume container for #{$context[:process_performer]}",
        date.iso8601,
        inputOf:process_id
    )


  #produce the packed items (outputOf)
  container_take(container_key)  # places them in batch
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
      date.iso8601,
      item[:unit],
      nil,
      process_id #outputOf
    )

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

#replace the container items
def container_put(container_key)
  items = $context[:batch]
  $containers[container_key][:items] = items
end

# all actions will perform graphql calls
# wraps the use actions in a process as both input and output
# if no process id is specified, it will create one
def use_batch(note, process_id: nil)
  items = $context[:batch]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]

  puts "graphql USE by #{performer} on #{items.count} items" 

  if(process_id == nil)
    process_id = $client.process(
      agent[:token],
      "use batch process #{note}",
      "use batch for #{agent[:label]}",
      date.iso8601
    )
    puts "created (use) process: #{process_id}"
  end

  items.each do |item|
    event_id = $client.use_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        note,
        date.iso8601,
        inputOf: process_id,
        outputOf: process_id
      )
    puts "Created Reflow OS Use event: #{event_id}"
  end
end

def modify_batch(note, process_id: nil)
  items = $context[:batch]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]

  puts "graphql MODIFY by #{performer} on #{items.count} items" 

  if(process_id == nil)
    process_id = $client.process(
      agent[:token],
      "modify process #{note}",
      "modify batch for #{agent[:label]}",
      date.iso8601
    )
    puts "created (modify) process: #{process_id}"
  end
  
  items.each do |item|
    event_id = $client.modify_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        note,
        date.iso8601,
        inputOf: process_id,
        outputOf: process_id
    )
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

#set context batch to failed items
def failed_take
  failed_items = $context[:batch_failed]
  $context[:batch] = failed_items
end

# perform a consume verb, if a fraction is specified operate on part of the batch, 
# default operate on everything
def consume_batch(process_id: nil)
  items = $context[:batch]
  performer = $context[:process_performer]
  puts "graphql CONSUME #{items.count} items by #{performer}"
  
  agent = $agents[performer]
  date = $context[:date]

  if(process_id == nil)
    process_id = $client.process(
      agent[:token],
      "consume batch process",
      "consume batch for #{agent[:label]}",
      date.iso8601
    )
    puts "created (consume) process: #{process_id}"
  end

  items.each do |item|
    event_id = $client.consume_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        "consume for #{$context[:process_performer]}",
        date.iso8601,
        inputOf:process_id
    )

    puts "Created Reflow OS Consume event: #{event_id}"
  end
end

# consume a single container resource
def action_consume_container(container_key)
  performer = $context[:process_performer]
  date = $context[:date]
  agent = $agents[performer]
  resource_key = $containers[container_key][:resource_key]
  
  puts "graphql CONSUME #{resource_key} by #{performer}" 
  item = $containers[container_key]
  event_id = $client.consume_one(
        agent[:token], 
        agent[:agent_id], 
        item[:id], 
        "consume container by #{$context[:process_performer]}",
        date.iso8601)

  puts "Created Reflow OS Consume container event: #{event_id}"
end

def produce_container(container_key, outputOf)
  manifest_items = $context[:batch]
  performer = $context[:process_performer] 
  puts "graphql PRODUCE #{container_key} with #{$containers[container_key][:items].count} items by #{performer}"
 
  agent = $agents[performer]
  date = $context[:date]
  resource_key = $containers[container_key][:resource_key]
  resource_label = $resources[resource_key][:label]
  unit_id = $resources[resource_key][:unit]
 
  #create a container resource in reflow os, put in the list of tracking id's as the manifest note  
  manifest = manifest_items.map{|item|item[:tracking_id]}.join(",")
  puts "manifest: #{manifest}"
  container_id = $client.produce_empty_container(
          agent[:token], 
          agent[:agent_id], 
          "#{resource_label} Container", 
          agent[:location],
          "#{resource_label} Container",
          "Manifest: #{manifest}",
          date.iso8601, 
          unit_id,
          outputOf
      ) #returns container id

  $containers[container_key][:id] = container_id
  puts "Created Reflow OS Container event: #{container_id}"
end

def action_produce_batch(items)
  performer = $context[:process_performer] 
  puts "graphql PRODUCE #{items.count} items by #{performer}"
end

# transfers each item in the context batch 
# from the current performer
# to the receiver
def transfer_batch(receiver, label)
  performer = $context[:process_performer]
  provider = $agents[performer]
  receiver = $agents[receiver]
  date = $context[:date]
  items = $context[:batch]
  location_id =  receiver[:location]

  items.each do |item|
    event_id = $client.transfer_one(
      provider[:token],
      provider[:agent_id],
      receiver[:agent_id],
      item[:id],
      "#{label} Batch Transfer",
      date.iso8601,
      location_id,
      item[:unit]) 
    puts "Created Reflow OS Transfer event: #{event_id}"
  end
end

# transfers each item in the context batch 
# from the current performer
# to the receiver
def transfer_custody_batch(receiver, label)
  performer = $context[:process_performer]
  provider = $agents[performer]
  receiver = $agents[receiver]
  date = $context[:date]
  items = $context[:batch]
  location_id =  receiver[:location]

  items.each do |item|
    event_id = $client.transfer_custody_one(
      provider[:token],
      provider[:agent_id],
      receiver[:agent_id],
      item[:id],
      "#{label} Batch Transfer Custody",
      date.iso8601,
      location_id,
      item[:unit]) 
    puts "Created Reflow OS Transfer Custody event: #{event_id}"
  end
end

#does a volume transfer on all items in the context batch
def transfer_volume(receiver, label)
  performer = $context[:process_performer]
  provider = $agents[performer]
  receiver = $agents[receiver]
  date = $context[:date]
  items = $context[:batch]
  location_id =  receiver[:location]

  items.each do |item|
    event_id = $client.transfer_volume(
      provider[:token],
      provider[:agent_id],
      receiver[:agent_id],
      item[:id],
      "#{label} Volume Transfer",
      date.iso8601,
      location_id,
      item[:unit],
      item[:amount]) 
    puts "Created Reflow OS Transfer event: #{event_id}"
  end
end

def transfer_container(container_key, provider, receiver)
 
  provider = $agents[provider]
  receiver = $agents[receiver]
  date = $context[:date]

  resource_key = $containers[container_key][:resource_key]
  resource_label = $resources[resource_key][:label]
  unit_id = $resources[resource_key][:unit]
  container_id = $containers[container_key][:id]
  location_id =  receiver[:location]

  puts "graphql TRANSFER of #{resource_key} Container from #{provider[:label]} to #{receiver[:label]}"
 
  #transfer from provider to receiver (by provider)
  event_id = $client.transfer_one(
    provider[:token],
    provider[:agent_id],
    receiver[:agent_id],
    container_id,
    "#{resource_label} Container Transfer",
    date.iso8601,
    location_id,
    unit_id) 

    puts "Created Reflow OS TRANSFER event: #{event_id}"
end

# pack a batch into the container specified by container_key
# side effect: produces a new resource and assigns it to the container key
def pack_container(container_key)

      performer = $context[:process_performer]
      agent = $agents[performer]
      date = $context[:date]

      process_id = $client.process(
        agent[:token],
        "pack process",
        "pack by #{agent[:label]}",
        date.iso8601
      )
      puts "created (pack) process: #{process_id}"

      #the consume action is always inputOf the process
      consume_batch(process_id: process_id) 
      
      container_put container_key

      #the produce action in the pack is outputOf the process
      produce_container(container_key, process_id)
end

#consumes the items in the batch, transforms to type of output
#each item in the batch will add the fraction to the unit of the output 
#and place the transformed result in the process batch
def transform_batch_to_volume(resource_key, fraction)
  in_items = $context[:batch]
  out_item = $resources[resource_key][:generator].call
  out_item[:unit] = $resources[resource_key][:unit]
  out_item[:amount] = in_items.count * fraction
  consume_batch
 
  resource_label = $resources[resource_key][:label]
  performer = $context[:process_performer]
  agent = $agents[performer]
  date = $context[:date]
 
  out_item[:id] = $client.produce_volume(
          agent[:token], 
          agent[:agent_id], 
          resource_label, 
          agent[:location],
          "transform batch to volume #{$context[:agent_key]} - #{$context[:date]}",
          out_item[:description],
          date.iso8601,
          out_item[:unit],
          out_item[:amount]
          )
  out_item[:created_by] = agent 
  out_item[:created_at_day] = $context[:date].iso8601

  $context[:batch] = [out_item]
end
