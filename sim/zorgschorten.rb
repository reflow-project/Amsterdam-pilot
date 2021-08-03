require_relative 'dsl.rb'

graph("Zorgschorten") do 

  #define agent and initial resources
  agent :a_hospital, "Hospital" do
    #baseline state
    resource :gown_in_use, "Gown Lot (in use)", Unit::Pool, "400-500" # gowns in use in the hospital (not a 'real' inventory)
    resource :gown_dirty_pool, "Gown (dirty)", Unit::Pool, "0" # gowns in the hamper in the hospital (not a 'real' inventory)
  end
  
  agent :a_tsc, "Textile Service Company" do 
    resource :gown_stock, "Gown (in stock)", Unit::Inventory, "1000" # in stock in the tsc
  end

  #this agent is considered 'jit', and only deals with lots
  agent :a_launderer, "Laundry Service"
  resource :gown_dirty_lot, "Gown Lot (dirty)", Unit::Lot  # lot used for transfer
  resource :gown_clean, "Gown Lot (clean)", Unit::Lot  # lot used for transfer
  resource :gown_ready_for_use, "Gown Lot", Unit::Lot # lot used for transfer

  # on delivery add the lot to the in use pool 
  # every day between 10 and 40 in use gowns are put in the hamper
  event :e_out_use, "Use (Discard)" do 
    simulation(:cron => "*/1" :amount => "10-40") do
      role :a_hospital, Role::USER 
      consume :gown_in_use # lower the in use pool
      produce :gown_dirty_pool # raise the dirty pool
    end
  end 

  # every seven days the dirty pool is picked up
  event :e_transfer_pickup, "pickup" do 
    simulate :cron => "*/7" do
      role :a_hospital, Role::PROVIDER 
      role :a_launderer, Role::RECEIVER 
      consume :gown_dirty_pool
      produce :gown_dirty_lot
      transfer :gown_dirty_lot 
    end
  end 

  # performs laundry for entire lot 1 day abter receiving :gown_dirty_lot
  event :e_laundry, "Work (laundry)" do
    simulate :on => :e_transfer_pickup, :with_delay => "1d" do
      role :a_launderer, Role::PERFORMER 
      consume :gown_dirty_lot
      produce :gown_clean
    end
  end 

  # transfers entire lot between 0-2 days after cleaning to tsc
  event :e_transfer_clean, "Transfer" do 
    simulate (:on => :e_laundry, :with_delay =>"0-2d") do
      role :a_launderer, Role::PROVIDER 
      role :a_tsc, Role::RECEIVER 
      transfer :gown_clean
    end
  end 

  # tcs inspect lot between 0-3 days after receiving
  event :e_inspect, "Modify (QI)" do 
    simulate(:on => :e_transfer_clean, :with_delay => "0-3d") do
      role :a_tsc, Role::PERFORMER 
      consume :gown_clean, "1.0f" 
      produce :gown_stock, "0.8-0.95f" # between 0.05 and 0.2 of the lot doesn't pass inspection (should raise inventory)
    end
  end  

  # every day, take between 1 and 10 gowns from 
  # the TSC stock and transfer them to the hospital
  event :e_transfer_delivery, "Transfer (Delivery)" do 
    simulation(:cron => "*/1", :amount => "1-10") do
      role :a_tsc, Role::PROVIDER 
      role :a_hospital, Role::RECEIVER 
      consume :gown_stock
      produce :gown_ready_for_use
      transfer :gown_ready_for_use
     end
  end 

  # on delivery add the lot to the in use pool 
  event :e_in_use, "Use (Wear)" do 
    simulation(:on => :e_transfer_delivery) do
      role :a_hospital, Role::USER 
      consume :gown_ready_for_use
      produce :gown_in_use #raise the in use pool
    end
  end 

end
