require_relative '../dsl.rb'
require 'securerandom'
# use / clean cycle only for now
# 
# only thirty days for dev purposes
#
# Open issues
# - for most 'transfer' actions it probably should become a move or transfer-custody, since i assume clean lease leases their gowns to the hospital...
#
# - i now modeled the transfers as batches -> gowns are consumed and containers are produced at the provider side, containers are consumed and the same gowns are produced on the receiver side, this could also be modeled with pickup / dropoff for (batches of) individual resources
#
# - i now model quality assurance and cleaning as modify in stead of accept
# because there is no 'deny' for the parts to be discarded 
# 
# - i defined gown_stock as an inventory because it would be interesting to see if we could lower / raise the inventory level, but how does it work when you have both the individual gowns (since they all have id's that we want to track) and want to track meta information...
#
# - we could think about 'using' laundry machine resources for example
#
simulation("Zorgschorten", Date.today, Date.today + 7) do 

  unit :u_piece, "om2:one", "#"

  resource :gown, "Gown", :u_piece do
    rid = SecureRandom.uuid
    # this id is not the reflow os id, but the id used by cleanlease to track the invidual gown
    {:tracking_id => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end

  # a container might actually have its own id (and a list of included items as description) but for now we assume they are anonymous batches (they do get their own id in reflow os though)
  # we only have one type of resource in the use cycle, but many collections of them
  # resource collections that have no owner per se, used for transfer
  # created on demand in Reflow OS as single transient economic resource from a batch of gowns
  container :gown_dirty_container, "Gown Container (dirty)", :gown 
  container :gown_clean, "Gown Container (clean)", :gown 
  container :gown_ready_for_use, "Gown Container", :gown 

  # OLVG
  # Either i can make more than one agent with one user account, or each agent is tied to a user account
  # Should be able to generate (fake) user accounts through graphql
  agent :a_hospital, "OLVG" do
      location 52.35871773455108, 4.916762398221842,
	 	"Oosterpark 9, 1091 AC Amsterdam",
		"OLVG locatie oost",
        "olvg.nl"

      pool :gown_in_use, "Gown Container (in use)", :gown, 10 # gowns in use in the hospital 
      pool :gown_dirty_pool, "Gown (dirty)", :gown # gowns in the hamper in the hospital, defaults to zero
  end
 
  # Clean Lease
  agent :a_tsc, "CleanLease_Service" do 
      location 51.47240440868687, 5.412460440524406,
	 	"De schakel 30, 5651 Eindhoven",
		"CleanLease Eindhoven",
		"Textile service provider"       

      #inventory :gown_stock, "Gown (in stock)", :gown, rand(800..1000) # in stock in the tsc
      inventory :gown_stock, "Gown (in stock)", :gown, 20 # in stock in the tsc
      pool :gown_discarded_pool, "Gown to be recycled", :gown # gowns that failed the Quality Inspection, defaults to zero initially
  end

  #this agent is considered 'jit', and only deals with containers
  # Clean Lease
  agent :a_launderer, "CleanLease_Laundry" do
      location 51.47240440868687, 5.412460440524406,
	 	"De schakel 30, 5651 Eindhoven",
		"CleanLease Eindhoven",
		"Textile service provider"       
  end

  agent :a_sorter, "Wieland" do
    location 52.51345006821827, 4.7785117343772345,
	 	"Handelsweg 8, 1521 NH Wormerveer",
		"Wieland Textiles",
		"wieland.nl"
  end
  
  agent :a_unraveler, "Denimtex" do
    location 52.2141945, 6.8415574
	 	"Josink Kolkweg 19, 7545 PR Enschede",
		"Denimtex",
		"denimtex.nl"
  end

  # every day between 5 and 10 in use gowns are put in the hamper 
  event :e_out_use, "Use (Discard)" do 
    schedule cron: 1 
    process do 
      as_performer :a_hospital 
      pool_take :gown_in_use, rand(5..10) 
      use_batch "used in emergency room" 
      pool_put :gown_dirty_pool 
    end
  end 
  
  #
  # every seven days the entire dirty pool is picked up
  #
  event :e_transfer_pickup, "pickup" do 
    schedule cron: 7  
    process do
      as_performer :a_hospital
      pool_take :gown_dirty_pool
      pack_container :gown_dirty_container
      transfer_container :gown_dirty_container, :a_hospital, :a_launderer 
    end
  end 

  # performs laundry for entire container 1 day and repacks as clean 
  event :e_laundry, "Modify (clean)" do
    schedule on_event: :e_transfer_pickup, with_delay: 1 
    process do
      as_performer :a_launderer
      unpack_container :gown_dirty_container 
      modify_batch "performed deep clean at 100 deg"
      pack_container :gown_clean
    end
  end 

  # transfers entire container between 0-2 days after cleaning to tsc, fantasy
  event :e_transfer_clean, "Transfer" do 
    schedule on_event: :e_laundry, with_delay: rand(0..2)
    process do
      as_performer :a_launderer
      transfer_container :gown_clean, :a_launderer, :a_tsc 
    end
  end 

  # tcs inspect container between 0-3 days after receiving, fantasy
  event :e_inspect, "Modify (QI)" do 
    schedule on_event: :e_transfer_clean, :with_delay => rand(0..2) 
    process do
      as_performer :a_tsc
      unpack_container :gown_clean
      modify_batch "peformed inspection"
      pass_batch rand(0.95..1)
      inventory_put :gown_stock
      failed_take
      pool_put :gown_discarded_pool
    end
  end

  event :e_recycle, "recycle discarded garments" do
    schedule on_event: :e_inspect, :with_delay => rand(0..2) 
    process do
      as_performer :a_tsc
      pool_take :gown_discarded_pool
      transfer_batch :a_sorter, "to recycle"
    end
  end  

  # every other day, take between 1 and 10 gowns from 
  # the TSC stock and transfer them to the hospital, fantasy
  event :e_transfer_delivery, "Transfer (Delivery)" do 
    schedule cron: 2 
    process do
      as_performer :a_tsc
      inventory_take :gown_stock, rand(1..10) 
      pack_container :gown_ready_for_use
      transfer_container :gown_ready_for_use, :a_tsc, :a_hospital 
     end
  end 

  # on delivery add the container to the in use pool
  event :e_available, "Produce (increase available gowns)" do 
    schedule on_event: :e_transfer_delivery 
    process do 
      as_performer :a_hospital
      unpack_container :gown_ready_for_use
      pool_put :gown_in_use
    end
  end 

end
