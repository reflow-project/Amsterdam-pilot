require_relative '../dsl.rb'
require 'securerandom'

simulation("Transfer", Date.today - 1, Date.today) do 

  resource :gown, "Gown" do
    rid = SecureRandom.uuid
    {:tracking_id => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end

  container :a_container, "Gown Container (dirty)", :gown 

  agent :a_hospital, "OLVG" do
    authenticate "AGENT_OLVG_EMAIL", "AGENT_OLVG_PASSWORD"
    location "AGENT_OLVG_LOCATION"
    pool :gowns, "Gowns", :gown, 1 #produces the one gown in the pool 
  end

  agent :a_launderer, "Clean Lease Laundry Service" do
    authenticate "AGENT_CLC_EMAIL", "AGENT_CLC_PASSWORD"
    location "AGENT_CLC_LOCATION"
  end

  event :test, "Test pack, unpack, transfer, use and modify" do 
    schedule cron: 1 
    process do 

      as_performer :a_hospital 
      pool_take :gowns, 1 
      use_batch "used in emergency room"
      pack_container :a_container  
      transfer_container :a_container, :a_hospital, :a_launderer 
      
      as_performer :a_launderer
      unpack_container :a_container 
      modify_batch "performed deep clean at 100 deg"

    end
  end 

end
