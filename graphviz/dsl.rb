#dsl for generating value flow diagrams with graphviz
LABEL_WIDTH = 10 # max characters
$cluster_count = 0

# print an agent
def agent(id, label)
  puts "#{id} [label=\"#{insert_breaks(label.gsub("\n","\\n"))}\" fixedsize=true, width=1.25, shape=circle, style=\"filled\", fillcolor=\"#43e272\", color=\"#4cb46c\" fontname=\"Helvetica\"];"
end

def resource(id, label)
  puts "#{id} [label=\"#{insert_breaks(label.gsub("\n","\\n"))}\", fixedsize=true, width=1.1 shape=square, style=\"filled\", fillcolor=\"#004576\", fontcolor=\"white\", color=\"#697d8a\" fontname=\"Helvetica\"];"
end

def event(id, label)
  puts "#{id} [label=\"#{insert_breaks(label.gsub("\n","\\n"))}\", fixedsize=true, width = 1.1, shape=square, style=\"rounded,filled\", fillcolor=\"#e2e2e2\", color=\"#b5b5b5\" fontname=\"Helvetica\"];"
end

def role(event, agent, role)
  puts "#{event} -> #{agent} [dir=none, style=\"dotted\" label= \" #{role} \", fontname=\"Helvetica\"]" 
end

def flow(ids)
  puts ids.join(" -> ") 
end

def insert_breaks(labeltext)
	words = labeltext.split(' ')
	newtext = []
	newline = ""
	words.each do | word |
		if (newline.length> 0 and
		  newline.length + word.length > LABEL_WIDTH)
		  newtext << newline		 	
		  newline = ""
		end
		newline += " " if newline.length> 0
		newline += word 
	end
	newtext << newline if newline.length> 0
	newtext.join("\n")
end

def graph(label)
  puts "digraph #{label} {"
  puts "rankdir=\"LR\";"
  puts "graph [compound=true];"
  puts ""
  yield
  puts "}"
end

def sub_graph(label)
  puts "subgraph cluster_#{$cluster_count} {"
  puts "label=\"#{label}\"" 
  puts ""
  yield
  puts "}"
  $cluster_count += 1
end
