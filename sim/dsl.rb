require 'date'

#dsl for generating value flow simulation 
module Role
  Provider = "ROLE_PROVIDER"
  Receiver = "ROLE_RECEIVER"
  Performer = "ROLE_PERFORMER"
end

# this simulation first generate all the necessary operations in a setup phase and a timetable
# then executes the setup phase and when it's done the timetable on entry at a time using graphql requests with delays in between
def simulation(label, date_start = Date.today, date_end = Date.today + 365)
  puts "#{date_start} -> #{date_end}"
  $planned_events = [] #array of days, each do contains array of event keys to process on that day
  $nr_of_days = (date_end - date_start).to_i
  $nr_of_days.times do  |index|
    $planned_events[index] = [] #no events planned
  end
  yield #setup / generate agents, resources and schedule events

  # show internal state after setup
  puts "--- SETUP ---"
  puts "RESOURCES"
  puts $resources
  puts "LOTS"
  puts $lots
  puts "POOLS"
  $pools.keys.each do |key|
    puts "#{key}: #{$pools[key][:items].count} (#{$pools[key][:agent_key]})"
  end
  puts "INVENTORIES"
  $inventories.keys.each do |key|
    puts "#{key}: #{$inventories[key][:items].count} (#{$inventories[key][:agent_key]})"
  end
  puts "AGENTS"
  puts $agents
  puts "EVENTS"
  #pp $planned_events
  #puts $processes

  puts "--- RUN SIMULATION ---"
  $nr_of_days.times do  |index|
    day = date_start + index #no events planned
    $planned_events[index].each do |event_key|
      puts "#{day}: processing event: #{event_key}"
      #execute the process
      $context = {} #clean the context for every call
      $processes[event_key].call
      sleep 0.1 #delay not to go to fast
    end
  end
end

# setup an agent
$context = {}
$agents = Hash.new
def agent(key, label)
  $agents[key] = {:label => label}
  $context[:agent_key] = key #used as context for block 
  yield if block_given?
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
        items << item
      end
  end
  $pools[key] = {:label => label, :resource_key => resource_key, :items => items, :agent_key => $context[:agent_key] }
end

# a collection of resources that we want to keep track of in the simulation AND in reflow os 
$inventories = Hash.new
def inventory(key, label, resource_key, amount = 0)
  raise "resource not found: #{type}" if not $resources.key? resource_key 
  items = []
  # generate the initial items 
  if(amount > 0)
      amount.times do 
        item = $resources[resource_key][:generator].call
        items << item
      end
  end
  $inventories[key] = {:label => label, :resource_key => resource_key, :items => items, :agent_key => $context[:agent_key] }
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
def schedule(cron=nil, on=nil, with_delay=nil) 
  event_key = $context[:event_key]
  if(cron != nil)
    $nr_of_days.times do |day_nr|
      if (day_nr % cron == 0)
        $planned_events[day_nr] << event_key 
      end
    end
  end
  #if cron is not nil, put the event key as value in the array of every day that matches 
  # for each day number between start and end date
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

#set the amount for the current context for a verb
def with_performer(agent)
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

# perform a consume verb, if a fraction is specified operate on part of the batch, 
# default operate on everything
def consume(resource_key, fraction = 1.0)
  # we set the default amount to be everything in the set at the moment
  amount = current_amount(resource_key) 
  
  #unless there is an explicit amount specified in the context
  if($context[:process_amount])
    amount = fraction * $context[:process_amount]
  end
  performer = $context[:process_performer]
  
  puts "perform consume #{amount} #{resource_key} by #{performer}"
end

def produce(resource_key, fraction = 1.0)
  # we set the default amount to be everything in the set at the moment
  amount = current_amount(resource_key) 
  #unless there is an explicit amount specified in the context
  if($context[:process_amount])
    amount = fraction * $context[:process_amount]
  end
  performer = $context[:process_performer]
  puts "perform produce #{amount} #{resource_key} by #{performer}"
end

def transfer(resource_key, provider, receiver, fraction = 1.0)
  # we set the default amount to be everything in the set at the moment
  amount = current_amount(resource_key) 
  
  #unless there is an explicit amount specified in the context
  if($context[:process_amount])
    amount = fraction * $context[:process_amount]
  end

  puts "perform transfer of #{amount} #{resource_key} from #{provider} to #{receiver}"
end
