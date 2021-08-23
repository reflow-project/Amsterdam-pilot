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

  # TODO create a resource (gown)
  #
  
  # query the current inventory level of a resource 
  def getResource(rid, token)
    result = ReflowOS::Client.query(ReflowOS::GetResourceQuery, context: {token: token})
    result.data.economic_resource.onhand_quantity.has_numerical_value
  end

  # raise or lower an inventories resource
  def updateResource(token, amount, do_raise, unit_id, rid, agent_id)
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
    result = ReflowOS::Client.query(ReflowOS::UpdateResourceQuery, context: {token: token}, variables: variables)
    result.data.create_economic_event.economic_event.id
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
