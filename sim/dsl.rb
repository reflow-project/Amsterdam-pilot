#dsl for generating value flow simulation 

# print an agent
def agent(id, label)
  puts "agent: #{id} #{label}"
end

def resource(id, label)
  puts "resource: #{id} #{label}"
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

