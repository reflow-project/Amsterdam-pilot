require_relative '../reflow_os_client.rb'

# reflow-os Make file location for make calls
$RO_MAKE_PATH="~/Projects/reflow_os/reflow-os/"
# regex for parsing the id from the make agent response
$ID_REGEX = /"id"\s=>\s"(?<id>\w+)"/
# reflow os client running locally on 4000
$client = ReflowOSClient.new

# makes an agent in reflow os through a make call
# returns the reflow id
def make_agent(email, pass, user, name)
  result = `cd #{$RO_MAKE_PATH};make email=#{email} pass=#{pass} user=#{user} name=#{name} tasks.create_user 2>&1`  
  if matches = result.match($ID_REGEX)
    return matches[:id]
  end
  #we should never come here, quit program
  puts "make agent failed, try from fresh db?"
  puts result
  exit
end

def make_agents(file)
  agent_tokens = %w(ADMIN OLVG CLS CLC)

    agent_tokens.each { |token| 
      email = "taco+#{token.downcase}@waag.org"
      pass = "Password123"
      user = token.downcase.capitalize
      name = token.downcase.capitalize

      #generate agents with the make command
      id = make_agent(email, pass, user, name)
      puts "created: #{token}: #{id}"
      file.write "AGENT_#{token}_EMAIL=#{email}\n"
      file.write "AGENT_#{token}_PASSWORD=#{pass}\n"
    }
end

#create the new environment file
File.open('.env', 'w') { |file| 
	make_agents(file) #also creates the admin unit, used for making locations and the unit
    token = $client.login("taco+admin@waag.org", "Password123")

	#create om2 unit and save to .env file
	om2_id = $client.unit(token,"om2:one", "#")
	file.write "UNIT_OM2=#{om2_id}\n"	
    
	# make locations and save to .env file
	# OLVG 
	location_id = $client.location(
		token,
	    52.35871773455108, 4.916762398221842,
	 	"Oosterpark 9, 1091 AC Amsterdam",
		"OLVG locatie oost",
        "olvg.nl")
	file.write "AGENT_OLVG_LOCATION=#{location_id}\n"

	# TSC 
	location_id = $client.location(
		token,
        51.47240440868687, 5.412460440524406,
	 	"De schakel 30, 5651 Eindhoven",
		"CleanLease Eindhoven",
		"Textile service provider")
	file.write "AGENT_CLS_LOCATION=#{location_id}\n"
	file.write "AGENT_CLC_LOCATION=#{location_id}\n"
}


