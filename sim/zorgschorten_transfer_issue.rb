require_relative 'dsl.rb'
require 'securerandom'

simulation("Transfer", Date.today - 1, Date.today) do 

  resource :gown, "Gown" do
    rid = SecureRandom.uuid
    {:tracking_id => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end

  lot :a_lot, "Gown Lot (dirty)", :gown 

  agent :a_hospital, "OLVG" do
    authenticate "AGENT_OLVG_EMAIL", "AGENT_OLVG_PASSWORD"
    location "AGENT_OLVG_LOCATION"
    pool :gowns, "Gowns", :gown, 1 #produces the one gown in the pool 
  end

  agent :a_tsc, "Clean Lease Service" do 
    authenticate "AGENT_CLS_EMAIL", "AGENT_CLS_PASSWORD"
    location "AGENT_CLS_LOCATION"
  end

  agent :a_launderer, "Clean Lease Laundry Service" do
    authenticate "AGENT_CLC_EMAIL", "AGENT_CLC_PASSWORD"
    location "AGENT_CLC_LOCATION"
  end

  event :test, "Test transfer lot and consume as receiver" do 
    schedule cron: 1 
    process do 

      as_performer :a_hospital 

      #take the one gown from the pool and produce a lot (destroying the gown)
      batch = pool_take :gowns, 1 # simulation
      action_consume_batch batch # graphql
      lot_put :a_lot, batch # simulation
      action_produce_lot :a_lot, batch  #graphql

      #transfer the lot
      action_transfer_lot :a_lot, :a_hospital, :a_launderer #graphql
      
      as_performer :a_launderer

      #try to consume the lot, fails
      action_consume_lot :a_lot  

    end
  end 

end
