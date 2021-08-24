# graphql client for reflowos running on localhost
require "graphql/client"
require "graphql/client/http"

module ReflowOS

    # setup graphql client
    HTTP = GraphQL::Client::HTTP.new("http://localhost:4009/api/graphql") do
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
        createSession(email: $email, password: $password) {
          token 
        }
    }
    GRAPHQL
    LoginQuery = ReflowOS::Client.parse(loginTemplate) #client.query expects this to be a constant

    # define me query
    #
    meTemplate = <<-'GRAPHQL'
    {me {
      email
      isConfirmed
      isInstanceAdmin
      user {
        id
        icon
        image
        name
        preferredUsername
      }
    }}
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
    mutation($event:EconomicEventCreateParams!) {
      createEconomicEvent(event:$event){
          economicEvent {
                  id,
                  resourceInventoriedAs{
                    id
                  }
          }
      }
    }
    GRAPHQL
    EventQuery = ReflowOS::Client.parse(eventTemplate) 
end

class ReflowOSClient

  # login to retrieve bearer token
  def login(email, password) 

    variables = {
      email: email,
      password: password
    }
    result = ReflowOS::Client.query(ReflowOS::LoginQuery, variables: variables)
    result.data.create_session.token #bearer token
  end

  # get details of logged in user (e.g. agent id)
  def me(token)
    result = ReflowOS::Client.query(ReflowOS::MeQuery, context: {token: token}) 
    result.data.me.user.id
  end

  # produce one resource 
  # token is bearer token used to perform as_agent
  # agent_id is the agent id that produces the resource
  # name is the name of the resource (what we're making)
  # tracking_identifier is the id that's used for tracking (eg. qr code in gown)
  # location_id should exist in reflow os
  # event_note says something about the event, let's include the simulated date here
  # res_note says something about the resource
  def produce_one(token, agent_id, name, tracking_identifier, location_id, event_note, res_note, stock_id = nil) 
    variables = {
      event: {
        note: event_note,
        action: "produce",
        provider: agent_id,
        receiver: agent_id,
        resourceQuantity: {
          "hasUnit": ENV["UNIT_OM2"], #maybe this unit should come from simulation?
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

    performEvent(token, variables)
  end

  # produce a new empty stock resource 
  # token is bearer token used to perform as_agent
  # agent_id is the agent id that produces the resource
  # name is the name of the resource (what we're making)
  # location_id should exist in reflow os
  # event_note says something about the event, let's include the simulated date here
  # res_note says something about the resource
  def produce_stock(token, agent_id, name, location_id, event_note, res_note) 
    variables = {
      event: {
        note: event_note,
        action: "produce",
        provider: agent_id,
        receiver: agent_id,
        resourceQuantity: {
          "hasUnit": ENV["UNIT_OM2"], #maybe this unit should come from simulation?
          "hasNumericalValue": 0
        }
      },
      newInventoriedResource: { 
        name: name,
        tags: [],
        note: res_note,
        currentLocation: location_id 
      }
    }
    performEvent(token, variables)
  end

  # TODO produce a lot
  #
 
  # TODO create / check for unit with label om2:one
  # 01FDSJXTEB1KHRQ4D3Q95WS95C in dev db
  
  # TODO consume a resource 
  
  # TODO transfer a resource

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
    performEvent(token, variables)
  end

  def performEvent(token, variables)
    result = ReflowOS::Client.query(ReflowOS::EventQuery, context: {token: token}, variables: variables)
    result.data.create_economic_event.economic_event.id
  end

  # query the current inventory level of a resource 
  def getResource(rid, token)
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
