#dsl for generating value flow simulation 
module Resource
  Pool = "RES_POOL" 
  Inventory = "RES_INVENTORY" 
  Lot = "RES_LOT" 
end

module Role
  Provider = "ROLE_PROVIDER"
  Receiver = "ROLE_RECEIVER"
  Performer = "ROLE_PERFORMER"
end

# print an agent
def agent(id, label)
  puts "agent: #{id} #{label}"
  yield if block_given?
end

def resource(id, label, type = nil, amount = nil)
  puts "resource: #{id} #{label}"
  puts "type: #{type}" if type != nil
  puts "amount: #{amount}" if amount != nil
end

def event(id, label)
  puts "event: #{id} #{label}"
  $cur_id = id
  yield
end

def role(agent, role)
  puts "role: #{$cur_id} #{agent}: #{role}"
end

def flow(ids)
  puts ids.join(" -> ") 
end

def graph(label)
  puts label
  yield
end

def init 
  puts "init"
  yield
end

# cron specifies frequency in days, amount is an amount to generate, 
# on specifes the name of an event that triggers the event, with_delay delays by a number of days
def schedule(cron = nil, amount = nil, on = nil, with_delay = nil) 
  puts "schedule"
  yield
end

# perform a consume verb, if a fraction is specified operate on part of the batch, 
# default operate on everything
def consume(resource_key, fraction = 1.0)
  puts "perform consume #{resource_key}"
end

def produce(resource_key, fraction = 1.0)
  puts "perform produce #{resource_key}"
end

def transfer(resource_key, fraction = 1.0)
  puts "perform transfer #{resource_key}"
end
