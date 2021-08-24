require_relative 'dsl.rb'
require 'securerandom'
# use / clean cycle only for now
# 
# only thirty days for dev purposes
#
# Open issues
# - for most 'transfer' actions it probably should become a move or transfer-custody, since i assume clean lease leases their gowns to the hospital...
#
# - i now modeled the transfers as batches -> gowns are consumed and lots are produced at the provider side, lots are consumed and the same gowns are produced on the receiver side, this could also be modeled with pickup / dropoff for (batches of) individual resources
#
# - i now model quality assurance and cleaning as modify in stead of accept
# because there is no 'deny' for the parts to be discarded 
# 
# - i defined gown_stock as an inventory because it would be interesting to see if we could lower / raise the inventory level, but how does it work when you have both the individual gowns (since they all have id's that we want to track) and want to track meta information...
#
# - we could think about 'using' laundry machine resources for example
#
simulation("Zorgschorten", Date.today, Date.today + 30) do 

  # base data that needs to be present in ENV: 
  #
  # - unit om:2 => ENV[UNIT_OM2]
  # - authentication for each agent ENV[AGENT_OLVG_EMAIL] etc
  # - location for each agent ENV[AGENT_OLVG_LOCATION] etc, to be passed during setup 
  resource :gown, "Gown" do
    rid = SecureRandom.uuid
    # this id is not the reflow os id, but the id used by cleanlease to track the invidual gown
    {:tracking_id => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end

  # a lot might acutally have it's own id (and a list of included items as description) but for now we assumen they are anonymous batches (they do get their own id in reflow os though)
  # we only have one type of resource in the use cycle, but many collections of them
  #resource collections that have no owner perse, used for transfer
  # created on demand in Reflow OS as single transient economic resource from a batch of gowns
  lot :gown_dirty_lot, "Gown Lot (dirty)", :gown 
  lot :gown_clean, "Gown Lot (clean)", :gown 
  lot :gown_ready_for_use, "Gown Lot", :gown 

  # OLVG
  # Either i can make more than one agent with one user account, or each agent is tied to a user account
  # Should be able to generate (fake) user accounts through graphql
  agent :a_hospital, "OLVG" do
      authenticate "AGENT_OLVG_EMAIL", "AGENT_OLVG_PASSWORD"
      location "AGENT_OLVG_LOCATION"
      #pool :gown_in_use, "Gown Lot (in use)", :gown, rand(400..500) # gowns in use in the hospital 
      pool :gown_in_use, "Gown Lot (in use)", :gown, 10 # gowns in use in the hospital 
      pool :gown_dirty_pool, "Gown (dirty)", :gown # gowns in the hamper in the hospital, defaults to zero
      # should be populated in reflow os at seed time with a produce?
      # or maybe a produce by tsc and and immediate transfer, 
  end
 
  # Clean Lease
  agent :a_tsc, "Clean Lease Service" do 
      authenticate "AGENT_CLS_EMAIL", "AGENT_CLS_PASSWORD"
      location "AGENT_CLS_LOCATION"
      #inventory :gown_stock, "Gown (in stock)", :gown, rand(800..1000) # in stock in the tsc
      inventory :gown_stock, "Gown (in stock)", :gown, 20 # in stock in the tsc
      # should be populated in reflow os at seed time with a produce?
  end

  #this agent is considered 'jit', and only deals with lots
  # Clean Lease
  agent :a_launderer, "Clean Lease Laundry Service" do
      authenticate "AGENT_CLC_EMAIL", "AGENT_CLC_PASSWORD"
      location "AGENT_CLC_LOCATION"
  end
  # on delivery add the lot to the in use pool 
  
  # every day between 5 and 10 in use gowns are put in the hamper (wild guessing)
  event :e_out_use, "Use (Discard)" do 
    schedule cron: 1 # every day
    process do 
      batch = pool_take :gown_in_use, rand(5..10) # take is not a verb
      puts batch
      as_performer :a_hospital # set current agent
      action_use_batch batch # register gowns as used in reflow os
      # NB now sometimes reflow os correctly says we're not authorized to use
      # => you can see in the output that there are gowns from the tsc stock
      # this is because the transfer is not implemented yet!
      pool_put batch, :gown_dirty_pool # move the gowns to the dirty pool
    end
  end 
 
  
  #
  # every seven days the dirty pool is picked up, fantasy
  #
  event :e_transfer_pickup, "pickup" do 
    schedule cron: 7  # every week 
    process do
      as_performer :a_hospital
      batch = pool_take :gown_dirty_pool # takes all
      action_consume_batch batch # removes the gowns from the hospital pool in reflow_os 
      lot_put :gown_dirty_lot, batch # put the dirty gowns in the dirty lot
      
      action_produce_lot :gown_dirty_lot, batch # lot should have own id, containing manifest of each gown in gowns, produced in reflow_os

      #### COMMONSPUB GRAPHQL IMPLEMENTED UNTIL HERE
      action_transfer_lot :gown_dirty_lot, :a_hospital, :a_launderer #transfer the batched gowns in reflow_os 
    end
  end 

  # performs laundry for entire lot 1 day after receiving :gown_dirty_lot, fantasy
  event :e_laundry, "Modify (clean)" do
    schedule on_event: :e_transfer_pickup, with_delay: 1 
    process do
      as_performer :a_launderer
      batch = lot_take :gown_dirty_lot # takes all items from lot
      action_consume :gown_dirty_lot  #consume current lot in reflow os
      action_modify_batch "clean", batch # perform the actual cleaning in reflow os, , assigning the lot id that was the source
      lot_put :gown_clean, batch
      action_produce_lot :gown_clean # produce new lot in reflow os
    end
  end 

  # transfers entire lot between 0-2 days after cleaning to tsc, fantasy
  event :e_transfer_clean, "Transfer" do 
    schedule on_event: :e_laundry, with_delay: rand(0..2)
    process do
      as_performer :a_launderer
      action_transfer_lot :gown_clean, :a_launderer, :a_tsc #transfer the batched gowns in reflow_os 
    end
  end 

  # tcs inspect lot between 0-3 days after receiving, fantasy
  event :e_inspect, "Modify (QI)" do 
    schedule on_event: :e_transfer_clean, :with_delay => rand(0..2) 
    process do
      as_performer :a_tsc
      batch = lot_take :gown_clean
      
      action_modify_batch "inspect", batch #inspects the whole batch
      amount_passed = (batch.count * rand(0.95..1)).to_i # between zero and three items fail the inspection
      passed = batch.take(amount_passed)
      failed = batch.drop(amount_passed)
      
      action_consume :gown_clean
      action_produce_batch passed  #add all passed items to the inventory
      inventory_put passed, :gown_stock #should raise level
    end
  end  

  # every other day, take between 1 and 10 gowns from 
  # the TSC stock and transfer them to the hospital, fantasy
  event :e_transfer_delivery, "Transfer (Delivery)" do 
    schedule cron: 2 
    process do
      as_performer :a_tsc
      batch = inventory_take :gown_stock, rand(1..10) #should lower level
      action_consume_batch batch #consume in reflow os 
      lot_put :gown_ready_for_use, batch
      action_produce_lot :gown_ready_for_use, batch # produce a lot in reflow os
      action_transfer_lot :gown_ready_for_use, :a_tsc, :a_hospital # transfer lot
     end
  end 

  # on delivery add the lot to the in use pool
  event :e_available, "Produce (increase available gowns)" do 
    schedule on_event: :e_transfer_delivery 
    process do 
      as_performer :a_hospital
      batch = lot_take :gown_ready_for_use
      action_consume :gown_ready_for_use
      action_produce_batch batch #create the batch items in reflow os
      pool_put(batch, :gown_in_use)
    end
  end 

end
