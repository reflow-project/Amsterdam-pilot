require_relative '../dsl.rb'
require 'securerandom'

simulation("Transfer", Date.today - 1, Date.today) do 

  unit :u_piece, "om2:one", "#"

  resource :gown, "Gown", :u_piece do
    rid = SecureRandom.uuid
    {:tracking_id => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end

  container :a_container, "Gown Container (dirty)", :gown 

  agent :a_hospital, "OLVG" do
    location 52.35871773455108, 4.916762398221842,
	 	"Oosterpark 9, 1091 AC Amsterdam",
		"OLVG locatie oost",
        "olvg.nl"
    pool :gowns, "Gowns", :gown, 1 #produces the one gown in the pool 
  end

  agent :a_launderer, "CleanLease_Laundry_Service" do
    location 51.47240440868687, 5.412460440524406,
	 	"De schakel 30, 5651 Eindhoven",
		"CleanLease Eindhoven",
		"Textile service provider"  
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

      #todo wrap unpack in vf:process, a_container inputOf, skirt batch outputOf 
      unpack_container :a_container 

      #todo wrap modify batch in vf:process, inputOf+OutputOf
      modify_batch "performed deep clean at 100 deg"

    end
  end 

end
