# graphql client for reflowos running on localhost
require "graphql/client"
require "graphql/client/http"
require 'dotenv/load'

module ReflowOS

    # setup graphql client 
    HTTP = GraphQL::Client::HTTP.new("http://localhost:4000/api/graphql") do
    # HTTP = GraphQL::Client::HTTP.new("http://135.181.35.156:4000/api/graphql") do
      def headers(context)
        headers = {}
        headers["User-Agent"] = "Simulation Client"
        if(context != nil and context[:token] != nil)
          headers["Authorization"] = "Bearer #{context[:token]}"
        end
        return headers
      end
    end 

    if(File.exist?('schema.json'))
      Schema = GraphQL::Client.load_schema("schema.json")
    else
      Schema = GraphQL::Client.load_schema(HTTP)
      GraphQL::Client.dump_schema(HTTP, "schema.json")
    end

    Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

    loginTemplate = <<-'GRAPHQL'
    mutation($email: String!, $password: String!) {
        login(emailOrUsername: $email, password: $password) {
          token 
        }
    }
    GRAPHQL
    LoginQuery = ReflowOS::Client.parse(loginTemplate) #client.query expects this to be a constant

	locationTemplate = <<-'GRAPHQL'
		mutation($location: SpatialThingCreateParams!){
			createSpatialThing(spatialThing: $location) {
    			spatialThing {
      				id
    			}
  			}	
	}
    GRAPHQL
    LocationQuery = ReflowOS::Client.parse(locationTemplate) #client.query expects this to be a constant


    # define me query
    #
    meTemplate = <<-'GRAPHQL'
    query{
      myAgent{
        id
      }
    }
        GRAPHQL
    MeQuery = ReflowOS::Client.parse(meTemplate) 

    getResourceTemplate = <<-'GRAPHQL'
    query($rid: ID!) {
          economicResource(id: $rid) {
                onhandQuantity {
                        hasNumericalValue
                            }
                    }
    }
    GRAPHQL
    GetResourceQuery = ReflowOS::Client.parse(getResourceTemplate) 

    #define the update query 
    eventTemplate = <<-'GRAPHQL'
    mutation($event:EconomicEventCreateParams!, $newInventoriedResource:EconomicResourceCreateParams) {
      createEconomicEvent(event:$event, newInventoriedResource:$newInventoriedResource){
          economicEvent {
                  id
                  resourceInventoriedAs {
                    id
                  }
                  toResourceInventoriedAs {
                    id
                  }
          }
      }
    }
    GRAPHQL
    EventQuery = ReflowOS::Client.parse(eventTemplate) 

    unitTemplate = <<-'GRAPHQL'
	mutation($unit:UnitCreateParams!) {
	  createUnit(unit: $unit) {
		unit {
		  id
		}
	  }
	}
    GRAPHQL
    UnitQuery = ReflowOS::Client.parse(unitTemplate) 

    processTemplate = <<-'GRAPHQL'
	mutation($process:ProcessCreateParams!) {
	  createProcess(process: $process) {
		process {
		  id
		}
	  }
	}
    GRAPHQL
    ProcessQuery = ReflowOS::Client.parse(processTemplate) 

end

class ReflowOSClient

  # constants used for make calls (to create users)
  $RO_MAKE_PATH=ENV['REFLOW_OS_PATH'] 
  $ID_REGEX = /"id"\s=>\s"(?<id>\w+)"/

  # makes an agent in reflow os through a make call
  # returns the reflow id of the created agent
  def make_agent(email, pass, user, name)
    result = `cd #{$RO_MAKE_PATH};make email=#{email} pass=#{pass} user=#{user} name=#{name} tasks.create_user 2>&1`  
    if matches = result.match($ID_REGEX)
      return matches[:id]
    end
    #we should never come here, quit program
    puts "make agent failed: #{name} #{email}, try from fresh db?"
    puts result
    return nil
  end


  # login to retrieve bearer token
  def login(email, password) 

    variables = {
      email: email,
      password: password
    }
    result = ReflowOS::Client.query(ReflowOS::LoginQuery, variables: variables)
    result.data.login.token #bearer token
  end

  # get details of logged in user (e.g. agent id)
  def me(token)
    result = ReflowOS::Client.query(ReflowOS::MeQuery, context: {token: token}) 
    result.data.my_agent.id
  end

  # create and return id for a om2:one unit
  def unit(token,label,symbol)
    variables = {
      unit: {
        label: label,
        symbol: symbol
      }
    }
    result = ReflowOS::Client.query(ReflowOS::UnitQuery, variables: variables, context: {token: token}) 
    result.data.create_unit.unit.id
  end

  # create process and return id
  def process(token, name, note, ts)
    variables = {
      process: {
        name: name,
        note: note,
        hasBeginning: ts,
        hasEnd: ts
      }
    }
    result = ReflowOS::Client.query(ReflowOS::ProcessQuery, variables: variables, context: {token: token}) 
    result.data.create_process.process.id
  end

  def location(token,lat,lon,address,name,note)
	variables = {
	  location: {
		name: name,
		alt: 0,
		lat: lat,
		long: lon,
		mappableAddress: address,
		note: note
	  }	
	}
	result = ReflowOS::Client.query(ReflowOS::LocationQuery, variables: variables, context: {token: token}) 
    result.data.create_spatial_thing.spatial_thing.id
  end

  # produce one piece resource 
  # token is bearer token used to perform as_agent
  # agent_id is the agent id that produces the resource
  # name is the name of the resource (what we're making)
  # tracking_identifier is the id that's used for tracking (eg. qr code in gown)
  # location_id should exist in reflow os
  # event_note says something about the event, let's include the simulated date here
  # res_note says something about the resource
  def produce_one(token, agent_id, name, tracking_identifier, location_id, event_note, res_note, ts, unit_id, stock_id = nil, output_of = nil) 
    variables = {
      event: {
        note: event_note,
        action: "produce",
        provider: agent_id,
        receiver: agent_id,
        hasPointInTime: ts,
        resourceQuantity: {
          "hasUnit": unit_id, 
          "hasNumericalValue": 1
        }
      },
      newInventoriedResource: { 
        trackingIdentifier: tracking_identifier,
        name: name,
        tags: [],
        note: res_note,
        currentLocation: location_id 
      }
    }

    # relate this resource to a stock if part of stock 
    variables[:newInventoriedResource][:contained_in] = stock_id if stock_id != nil

    # if a process output is specified pass that too
    variables[:event][:outputOf] = output_of if output_of != nil
    
    result = performEvent(token, variables)
    result.resource_inventoried_as.id #return value is created item id
  end

  #produce a resource that is a volume (has unit and amount => other than om2:one)
  #e.g. kg, 200
  def produce_volume(token, agent_id, name, location_id, event_note, res_note, ts, unit_id, amount)
    variables = {
      event: {
        note: event_note,
        action: "produce",
        provider: agent_id,
        receiver: agent_id,
        hasPointInTime: ts,
        resourceQuantity: {
          "hasUnit": unit_id, 
          "hasNumericalValue": amount 
        }
      },
      newInventoriedResource: { 
        name: name,
        tags: [],
        note: res_note,
        currentLocation: location_id 
      }
    }

    result = performEvent(token, variables)
    result.resource_inventoried_as.id #return value is created item id

  end

  # produce a new empty container resource (stock or transfer container)
  # token is bearer token used to perform as_agent
  # agent_id is the agent id that produces the resource
  # name is the name of the resource (what we're making)
  # location_id should exist in reflow os
  # event_note says something about the event, let's include the simulated date here
  # res_note says something about the resource
  def produce_empty_container(token, agent_id, name, location_id, event_note, res_note, ts, unit_id, outputOf) 
    variables = {
      event: {
        note: event_note,
        hasPointInTime: ts,
        action: "produce",
        provider: agent_id,
        receiver: agent_id,
        resourceQuantity: {
          "hasUnit": unit_id, 
          "hasNumericalValue": 0
        },
        outputOf: outputOf
      },
      newInventoriedResource: { 
        name: name,
        tags: [],
        note: res_note,
        currentLocation: location_id 
      }
    }
    result = performEvent(token, variables)
    result.resource_inventoried_as.id #return value is created item id
  end

  # Use a single resource
  # Does nothing to the resource except log an event
  def use_one(token, agent_id, resource_id, event_note, ts, inputOf: nil, outputOf: nil)
    variables = {
      event: {
        note: event_note,
        action: "use",
        provider: agent_id,
        receiver: agent_id,
        hasPointInTime: ts,
        resourceInventoriedAs: resource_id 
      }
    }

    variables[:event][:inputOf] = inputOf if inputOf != nil
    variables[:event][:outputOf] = outputOf if outputOf != nil

    result = performEvent(token, variables)
    result.id #return value is event id
  end
 
  # Modify a single resource
  # Does nothing to the resource except log an event
  def modify_one(token, agent_id, resource_id, event_note, ts, inputOf: nil, outputOf: nil)
    variables = {
      event: {
        note: event_note,
        action: "modify",
        provider: agent_id,
        receiver: agent_id,
        hasPointInTime: ts,
        resourceInventoriedAs: resource_id 
      }
    }

    variables[:event][:inputOf] = inputOf if inputOf != nil
    variables[:event][:outputOf] = outputOf if outputOf != nil

    result = performEvent(token, variables)
    result.id #return value is event id
  end

  # TODO create / check for unit with label om2:one
  # 01FDSJXTEB1KHRQ4D3Q95WS95C in dev db
  
  # consume a resource 
  def consume_one(token, agent_id, resource_id, event_note, ts, inputOf: nil)
    variables = {
      event: {
        note: event_note,
        action: "consume",
        provider: agent_id,
        receiver: agent_id,
        hasPointInTime: ts,
        resourceInventoriedAs: resource_id 
      }
    }
    
    variables[:event][:inputOf] = inputOf if inputOf != nil

    result = performEvent(token, variables)
    result.id #return value is event id
  end
 
  def transfer_volume(token, provider_id, receiver_id, resource_id, event_note, ts, location_id, unit, amount)
    variables = {
      event: {
        note: event_note,
        action: "transfer",
        provider: provider_id,
        receiver: receiver_id,
        hasPointInTime: ts,
        resourceInventoriedAs: resource_id,
        #TODO probably also need to specify the volume id on the receiving side
        atLocation: location_id, 
        resourceQuantity: {
          hasNumericalValue: amount,
          hasUnit: unit 
        }
      }
    }
    
    result = performEvent(token, variables)
    result.id 
  end

  # transfer a resource, (th)
  def transfer_one(token, provider_id, receiver_id, resource_id, event_note, ts, location_id, unit_id)
    variables = {
      event: {
        note: event_note,
        action: "transfer",
        provider: provider_id,
        receiver: receiver_id,
        hasPointInTime: ts,
        toResourceInventoriedAs: resource_id,
        atLocation: location_id, #this is not the location it ends up after the event...
        resourceQuantity: {
          hasNumericalValue: 1,
          hasUnit: unit_id
        }
      }
    }
    
    result = performEvent(token, variables)
    result.id #return value is event id
  end

  def transfer_custody_one(token, provider_id, receiver_id, resource_id, event_note, ts, location_id, unit_id)
    variables = {
      event: {
        note: event_note,
        action: "transfer-custody",
        provider: provider_id,
        receiver: receiver_id,
        hasPointInTime: ts,
        toResourceInventoriedAs: resource_id,
        atLocation: location_id, #this is not the location it ends up after the event...
        resourceQuantity: {
          hasNumericalValue: 1,
          hasUnit: unit_id 
        }
      }
    }
    
    result = performEvent(token, variables)
    result.id #return value is event id
  end

  def move_one(token, provider_id, receiver_id, resource_id, event_note, ts, location_id, unit_id)
    variables = {
      event: {
        note: event_note,
        action: "move",
        provider: provider_id,
        receiver: receiver_id,
        hasPointInTime: ts,
        toResourceInventoriedAs: resource_id,
        atLocation: location_id, #this is not the location it ends up after the event...
        resourceQuantity: {
          hasNumericalValue: 1,
          hasUnit: unit_id
        }
      }
    }
    
    result = performEvent(token, variables)
    result.id #return value is event id
  end


  # raise or lower an existing inventoried resource
  # used by swap shop
  def updateInventory(token, agent_id, rid, amount, unit_id, do_raise)
    variables = {
      event: {
        note: "update event",
        action: do_raise ? "raise" : "lower",
        provider: agent_id, 
        receiver: agent_id, 
        resourceInventoriedAs: rid,
        resourceQuantity: {
          hasUnit: unit_id, 
          hasNumericalValue: amount 
        }
      }
    }
    result = performEvent(token, variables)
    result.id #return value is event id
  end

  Result = Struct.new(:id) #fake a good result TODO: fix this

  def performEvent(token, variables)
    sleep 0.1 #delay not to go to fast
    result = ReflowOS::Client.query(ReflowOS::EventQuery, context: {token: token}, variables: variables)
    if result == nil or result.data == nil or result.data.create_economic_event == nil
      puts "REFLOW OS ERROR!!!: #{result.original_hash["errors"][0]["message"]} variables: #{variables}"
      return Result.new("_failed_")
    end
    # for debugging uncomment lines below
    # puts "---\n  PERFORMING EVENT: #{variables} ---\n"
    # puts "#{result.original_hash}\n"
    result.data.create_economic_event.economic_event
  end

  # query the current inventory level of a resource 
  def getResource(rid, token)
    sleep 0.1 #delay not to go to fast
    result = ReflowOS::Client.query(ReflowOS::GetResourceQuery, context: {token: token})
    result.data.economic_resource.onhand_quantity.has_numerical_value
  end

end

# # create a resource
# # mutation
# mutation doCreateResource($content:UploadInput, $resource:ResourceInput){
#   createResource(content:$content, resource:$resource){
#     id,
#     content{
#       id
#     }
#   } 
# }
