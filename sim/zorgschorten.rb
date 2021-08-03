require_relative 'dsl.rb'

graph("Zorgschorten") do 

  #define agent and initial resources
  #baseline state
  # Resource::Pool is a collection of resources, tied to an agent that we need to keep track of in the simulation 
  # but the collection does not necessarily exist as an explicit inventory in reflow_os
  # (maybe in reflow_os it's just individual gowns)
  # Resource::Inventory should exist as an inventory in reflow_os
  # Resource::Lot is group of items that can be transferred
  #
  agent :a_hospital, "Hospital" do
    resource :gown_in_use, "Gown Lot (in use)", Resource::Pool, "400-500" # gowns in use in the hospital 
    resource :gown_dirty_pool, "Gown (dirty)", Resource::Pool, "0" # gowns in the hamper in the hospital 
  end
  
  agent :a_tsc, "Textile Service Company" do 
    resource :gown_stock, "Gown (in stock)", Resource::Inventory, "1000" # in stock in the tsc
  end

  #this agent is considered 'jit', and only deals with lots
  agent :a_launderer, "Laundry Service"

  #resources that have now owner, used for transfer
  resource :gown_dirty_lot, "Gown Lot (dirty)", Resource::Lot  
  resource :gown_clean, "Gown Lot (clean)", Resource::Lot  
  resource :gown_ready_for_use, "Gown Lot", Resource::Lot 

  # on delivery add the lot to the in use pool 
  # every day between 10 and 40 in use gowns are put in the hamper
  event :e_out_use, "Use (Discard)" do 
    simulation(:cron => "*/1" :amount => "10-40") do
      role :a_hospital, Role::Performer
      consume :gown_in_use # lower the in use pool
      produce :gown_dirty_pool # raise the dirty pool
    end
  end 

  # every seven days the dirty pool is picked up
  event :e_transfer_pickup, "pickup" do 
    simulate :cron => "*/7" do
      role :a_hospital, Role::Provider 
      role :a_launderer, Role::Receiver 
      consume :gown_dirty_pool # lowers the pool to 0
      produce :gown_dirty_lot # with the total amount in the pool
      transfer :gown_dirty_lot 
    end
  end 

  # performs laundry for entire lot 1 day abter receiving :gown_dirty_lot
  event :e_laundry, "Work (laundry)" do
    simulate :on => :e_transfer_pickup, :with_delay => "1d" do
      role :a_launderer, Role::Performer 
      consume :gown_dirty_lot
      produce :gown_clean
    end
  end 

  # transfers entire lot between 0-2 days after cleaning to tsc
  event :e_transfer_clean, "Transfer" do 
    simulate (:on => :e_laundry, :with_delay =>"0-2d") do
      role :a_launderer, Role::Provider 
      role :a_tsc, Role::Receiver 
      transfer :gown_clean
    end
  end 

  # tcs inspect lot between 0-3 days after receiving
  event :e_inspect, "Modify (QI)" do 
    simulate(:on => :e_transfer_clean, :with_delay => "0-3d") do
      role :a_tsc, Role::Performer 
      consume :gown_clean, "1.0f" 
      produce :gown_stock, "0.8-0.95f" # between 0.05 and 0.2 of the lot doesn't pass inspection (should raise inventory)
    end
  end  

  # every day, take between 1 and 10 gowns from 
  # the TSC stock and transfer them to the hospital
  event :e_transfer_delivery, "Transfer (Delivery)" do 
    simulation(:cron => "*/1", :amount => "1-10") do
      role :a_tsc, Role::Provider 
      role :a_hospital, Role::Receiver 
      consume :gown_stock
      produce :gown_ready_for_use
      transfer :gown_ready_for_use
     end
  end 

  # on delivery add the lot to the in use pool 
  event :e_in_use, "Use (Wear)" do 
    simulation(:on => :e_transfer_delivery) do
      role :a_hospital, Role::Performer
      consume :gown_ready_for_use
      produce :gown_in_use #raise the in use pool
    end
  end 

end
