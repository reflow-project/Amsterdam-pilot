# graphql client for reflowos running on localhost
require "graphql/client"
require "graphql/client/http"
require 'dotenv/load'

Dotenv.require_keys("SWAPSHOP_EMAIL", "SWAPSHOP_PASSWORD")

module ReflowOS
    # setup graphql client
    HTTP = GraphQL::Client::HTTP.new("http://localhost:4009/api/graphql") do
      def headers(context)
        headers = {}
        headers["User-Agent"] = "Swapshop Client"
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

    # define login query
    email = ENV['SWAPSHOP_EMAIL']
    password = ENV['SWAPSHOP_PASSWORD']
    
    loginTemplate = <<-'GRAPHQL'
mutation {
    createSession(email: "%s", password: "%s") {
      token 
    }
}
    GRAPHQL
    LoginQuery = ReflowOS::Client.parse(loginTemplate % [email, password]) #client.query expects this to be a constant

    # define me query
    #
    meTemplate = <<-'GRAPHQL'
{me {
  email
  isConfirmed
  isInstanceAdmin
  user {
    icon
    image
    name
    preferredUsername
  }
}}
    GRAPHQL
    MeQuery = ReflowOS::Client.parse(meTemplate) 


    # these resources are made by hand and should exist in the database!
    SWAPSHOP_RESOURCE_ID ="01FAEV113XMG6KEE91GTAM52GX"
    SWAPSHOP_AGENT_ID = "01F9VN1M42RTS4JDCK278VZCMT"
    SWAPSHOP_UNIT_ID = "01F9X1XCVD7KPF0X21EDQPKCHY" 

    getResourceTemplate = <<-'GRAPHQL'
    query {
          economicResource(id:"01FAEV113XMG6KEE91GTAM52GX") {
                onhandQuantity {
                        hasNumericalValue
                            }
                    }
    }
    GRAPHQL
    GetResourceQuery = ReflowOS::Client.parse(getResourceTemplate) 

    #define the update query 
    updateResourceTemplate = <<-'GRAPHQL'
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
    UpdateResourceQuery = ReflowOS::Client.parse(updateResourceTemplate) 

end


class ReflowOSClient
 
  # setup the 
  def initialize
    result = ReflowOS::Client.query(ReflowOS::LoginQuery)
    @token = result.data.create_session.token #bearer token
    puts @token
  end

  # do a query to show the logged-in swapshop user
  def me
    result = ReflowOS::Client.query(ReflowOS::MeQuery, context: {token: @token}) #passing the bearer token in the context puts it in the header, effectively binding to the current session
    result.data.me
  end

  # query the current inventory level in reflow os
  def getInventoryLevel
    result = ReflowOS::Client.query(ReflowOS::GetResourceQuery, context: {token: @token})
    result.data.economic_resource.onhand_quantity.has_numerical_value
  end

  def updateInventoryLevel(amount, do_raise)
    variables = {
      event: {
        note: "update event",
        action: do_raise ? "raise" : "lower",
        provider: ReflowOS::SWAPSHOP_AGENT_ID,
        receiver: ReflowOS::SWAPSHOP_AGENT_ID,
        resourceInventoriedAs: ReflowOS::SWAPSHOP_RESOURCE_ID,
        resourceQuantity: {
          hasUnit: ReflowOS::SWAPSHOP_UNIT_ID, 
          hasNumericalValue: amount 
        }
      }
    }
    result = ReflowOS::Client.query(ReflowOS::UpdateResourceQuery, context: {token: @token}, variables: variables)
    result.data.create_economic_event.economic_event.id
  end

end

# first create a location, and a unit for the offer (in the explorer)
# check that dummy mutation with swapshop user exists (create a resource for amsterdam community)
# TODO find out how i can filter Units on label to see if it exists based on something i have control over
# also pagination doesn't seem to work on this graphql implementation
# template = <<-'GRAPHQL'
# query{
#    unit(id:"01F9X1XCVD7KPF0X21EDQPKCHY") {
#      id,
#      label,
#      symbol
#    }
#  }
# GRAPHQL
# UnitCheck = client.parse template
# result = client.query(UnitCheck, context: {token: token}) 
# unit_valid = (result.data.unit.label == "Swappable")
# 
# template = <<-'GRAPHQL'
# query{
#    spatialThing(id:"01F9X2WXHP5N9467X0W728F02C") {
#      id,
# 	 name,
# 	 note
#    }
#  }
# GRAPHQL
# LocationCheck = client.parse template
# result = client.query(LocationCheck, context: {token: token}) 
# location_valid = (result.data.spatial_thing.name == "The Swapshop Amsterdam ")
# TODO how can i update the name to remove the trailing space with a mutation

# we have made a resource by hand with id: 01FAEP3MNRKSAFDHY5DWNZEQVQ
# let's update this resource to a new level

# if(unit_valid && location_valid)
# 
# 	template = <<-'GRAPHQL'
# mutation {
#   createOffer(intent: {
#       action:"produce",
#       name: "Swapshop",
#       note: "second hand stuff" 
#       atLocation: "01F9X2WXHP5N9467X0W728F02C",
#       availableQuantity: {hasUnit: "01F9X1XCVD7KPF0X21EDQPKCHY", hasNumericalValue: 1},
#     }
#   ) {
#     intent {
#       id
#       name
#       note
#     }
#   }
# }
# GRAPHQL

# stuff made by hand in explorer
# 01F9X2WXHP5N9467X0W728F02C
# mutation {
#   createSpatialThing(
#     spatialThing: {
#     alt: 17,
#     lat: 52.3829895,
#     long: 4.8844759,
#     mappableAddress: "Haarlemmerdijk 89 1013 KC Amsterdam",
#     name: "The Swapshop Amsterdam ",
#     note: "The Swapshop is een sociale start-up. Onze missie is om de levensduur van kleding en andere fashion items te verlengen en van swappen de norm te maken. "
#   }) {
#     spatialThing {
#       id
#       name
#       lat
#       long
#       long
#       mappableAddress
#       note
#     }
#   }
# }


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
# 
# # query variables 
# {
#   "content": {
#     "url": "http://the-swapshop.com",
#     "upload": null
#   },
#   "resource" :{
#     "name": "TotalInventory",
#     "level": "0"
#   }
# }
# result
# {
#   "data": {
#     "createResource": {
#       "content": {
#         "id": "01FAEP3MN3VNDGE3GKF0NF9MS1"
#       },
#       "id": "01FAEP3MNRKSAFDHY5DWNZEQVQ"
#     }
#   }
# }
