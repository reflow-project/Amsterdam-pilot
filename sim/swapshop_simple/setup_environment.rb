# reflow-os Make file location for make calls
$RO_MAKE_PATH="~/Projects/reflow_os/reflow-os/"

# clean reflow os docker database instance
puts "removing docker containers, data directory and performing make setup"
`docker container stop reflow_release_search_1 reflow_release_db_1`
`docker container rm reflow_release_search_1 reflow_release_db_1`
`rm -rf #{$RO_MAKE_PATH}/bonfire/data`
`cd #{$RO_MAKE_PATH}; make setup`

# by doing a couple of graphql calls and make calls to a reflow os running on localhost:4000

# makes an agent in reflow os through a make call
# returns the reflow id
$ID_REGEX = /"id"\s=>\s"(?<id>\w+)"/
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

agent_tokens = %w(SWAPSHOP16 CONSUMER16 WIELAND16 REPAIRSHOP16)

agent_tokens.each { |token| 
  email = "#{token.downcase}@waag.org"
  pass = "Password123"
  user = token.downcase.capitalize
  name = token.downcase.capitalize

  #first generate all agents with the make command
  puts "peforming make agent"
  id = make_agent(email, pass, user, name)
  puts "#{token}_EMAIL = #{email}"
  puts "#{token}_PASSWORD = #{pass}"
  puts "#{token}_ID = #{id}"
  sleep 10 
}
