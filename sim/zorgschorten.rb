require_relative 'dsl.rb'
require 'securerandom'

#only thirty days for dev purposes
simulation("Zorgschorten", Date.today, Date.today + 30) do 

# set an optional start date and end date for the simulation
# default is today as start date and 1 year of simulated events
  # first we schedule 'root event' that have :cron set
  # then we schedule 'dependent events' that have :on set
  # the schedule is a table with dates as keys, and as value a generated struct that contains everything to perform an action on a resource by and agent
  # the simulation should internally keep track of what individual resources are transferred from one pool to another
  # use / clean cycle only for now
 
  # gowns in use in the hospital 
  resource :gown, "Gown" do
    rid = SecureRandom.uuid
    # this id is not the reflow os id, but the id used by cleanlease to track the invidual gown
    {:rid => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end

  # a lot might acutally have it's own id (and a list of included items as description) but for now we assumen they are anonymous batches (they do get their own id in reflow os though)
  # we only have one type of resource in the use cycle, but many collections of them
  #resource collections that have no owner perse, used for transfer
  lot :gown_dirty_lot, "Gown Lot (dirty)", :gown 
  lot :gown_clean, "Gown Lot (clean)", :gown 
  lot :gown_ready_for_use, "Gown Lot", :gown 

  # OLVG
  # Either i can make more than one agent with one user account, or each agent is tied to a user account
  # Should be able to generate (fake) user accounts through graphql
  agent :a_hospital, "OLVG" do
      pool :gown_in_use, "Gown Lot (in use)", :gown, rand(400..500) # gowns in use in the hospital 
      pool :gown_dirty_pool, "Gown (dirty)", :gown # gowns in the hamper in the hospital, defaults to zero
  end
 
  # Clean Lease
  agent :a_tsc, "Clean Lease Service" do 
      inventory :gown_stock, "Gown (in stock)", :gown, rand(800..1000) # in stock in the tsc
  end

  #this agent is considered 'jit', and only deals with lots
  # Clean Lease
  agent :a_launderer, "Clean Lease Laundry Service"
  # on delivery add the lot to the in use pool 
  
  # every day between 10 and 40 in use gowns are put in the hamper
  event :e_out_use, "Use (Discard)" do 
    schedule cron: 1 # every day
    process do 
      batch = pool_take :gown_in_use, rand(5..10) # take is not a verb
      as_performer :a_hospital # set current agent
      action_use_batch batch # register gowns as used in reflow os
      pool_put batch, :gown_dirty_pool # move the gowns to the dirty pool
    end
  end 

  # every seven days the dirty pool is picked up
  event :e_transfer_pickup, "pickup" do 
    schedule cron: 7  # every week 
    process do
      as_performer :a_hospital
      batch = pool_take :gown_dirty_pool # takes all
      action_consume_batch batch# removes the gowns from the hospital inventory in reflow_os 
      lot_put :gown_dirty_lot, batch #put the dirty gowns in the dirty lot
      action_produce_lot :gown_dirty_lot # lot should have own id, containing manifest of each gown in gowns, produced in reflow_os
      action_transfer :gown_dirty_lot, :a_hospital, :a_launderer #transfer the batched gowns in reflow_os 
    end
  end 

  # performs laundry for entire lot 1 day after receiving :gown_dirty_lot
  event :e_laundry, "Modify (clean)" do
    schedule on_event: :e_transfer_pickup, with_delay: 1 
    process do
      as_performer :a_launderer
      batch = lot_take :gown_dirty_lot # takes all items from lot
      action_consume :gown_dirty_lot  #consume current lot in reflow os
      action_modify_batch "clean", batch # perform the actual cleaning in reflow os
      lot_put :gown_clean, batch
      action_produce_lot :gown_clean # produce new lot in reflow os
    end
  end 

  # # transfers entire lot between 0-2 days after cleaning to tsc
  # event :e_transfer_clean, "Transfer" do 
  #   schedule :on => :e_laundry, :with_delay => rand(0..2)  do
  #     role :a_launderer, Role::Provider 
  #     role :a_tsc, Role::Receiver 
  #     transfer :gown_clean
  #   end
  # end 

  # # tcs inspect lot between 0-3 days after receiving
  # event :e_inspect, "Modify (QI)" do 
  #   schedule :on => :e_transfer_clean, :with_delay => rand(0..2) do
  #     role :a_tsc, Role::Performer 
  #     consume :gown_clean, "1.0" 
  #     produce :gown_stock, "0.8-0.95" # between 0.05 and 0.2 of the lot doesn't pass inspection (should raise inventory)
  #   end
  # end  

  # # every day, take between 1 and 10 gowns from 
  # # the TSC stock and transfer them to the hospital
  # event :e_transfer_delivery, "Transfer (Delivery)" do 
  #   schedule :cron => "*/1", :with_amount => rand(1..10) do
  #     role :a_tsc, Role::Provider 
  #     role :a_hospital, Role::Receiver 
  #     consume :gown_stock
  #     produce :gown_ready_for_use
  #     transfer :gown_ready_for_use
  #    end
  # end 

  # # on delivery add the lot to the in use pool 
  # event :e_in_use, "Use (Wear)" do 
  #   schedule :on => :e_transfer_delivery do
  #     role :a_hospital, Role::Performer
  #     consume :gown_ready_for_use
  #     produce :gown_in_use #raise the in use pool
  #   end
  # end 

end
