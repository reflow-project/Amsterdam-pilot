#dsl for generating value flow diagrams with graphviz

# print an agent
def agent(id, label)
  puts "#{id} [label=\"#{label.gsub("\n","\\n")}\" fixedsize=true, width=1.25, shape=circle, style=\"filled\", fillcolor=\"#43e272\", color=\"#4cb46c\" fontname=\"Helvetica\"];"
end

def resource(id, label)
  puts "#{id} [label=\"#{label.gsub("\n","\\n")}\", fixedsize=true, width=1.1 shape=square, style=\"filled\", fillcolor=\"#004576\", fontcolor=\"white\", color=\"#697d8a\" fontname=\"Helvetica\"];"
end

def event(id, label)
  puts "#{id} [label=\"#{label.gsub("\n","\\n")}\", fixedsize=true, width = 1.1, shape=square, style=\"rounded,filled\", fillcolor=\"#e2e2e2\", color=\"#b5b5b5\" fontname=\"Helvetica\"];"
end

def role(event, agent, role)
  puts "#{event} -> #{agent} [dir=none, label= \" #{role} \", fontname=\"Helvetica\"]" 
end

def flow(ids)
  puts ids.join(" -> ") 
end

def graph(label)
  puts "digraph #{label} {"
  puts "rankdir=\"LR\""
  puts ""
  yield
  puts "}"
end

