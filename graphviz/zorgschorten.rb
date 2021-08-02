require_relative 'dsl.rb'

graph("Zorgschorten") {

  agent :a_hospital, "Hospital"
  agent :a_laundry, "Laundry Service"
  agent :a_tsc, "Textile Service Company"

  resource :r_gown_dirty, "Gown Lot (dirty)"
  resource :r_gown_dirty2, "Gown Lot (dirty)"
  resource :r_gown_clean, "Gown Lot (clean)"
  resource :r_gown_clean2, "Gown Lot (clean)"
  resource :r_gown_inv_up, "Gown Vol (inv up)"
  resource :r_gown_inv_down, "Gown Vol (inv down)"

  event :e_pickup, "Transfer (pickup)" 
  event :e_work, "Work (laundry)" 
  event :e_pickup_tcs, "Transfer" 
  event :e_qi, "Modify (QI)" 
  event :e_pickup_hospital, "Transfer (Delivery)" 
  event :e_use, "Use (Wear)"

  role :e_pickup, :a_hospital, "provider"
  role :e_pickup, :a_laundry, "receiver"
  role :e_work, :a_laundry, "performer"
  role :e_pickup_tcs, :a_laundry, "provider"
  role :e_qi, :a_tsc, "inspector"
  role :e_pickup_hospital, :a_tsc, "provider"
  role :e_pickup_hospital, :a_hospital, "receiver"
  role :e_use, :a_hospital, "user"

  flow [:r_gown_dirty,:e_pickup,:r_gown_dirty2,:e_work,:r_gown_clean,:e_pickup_tcs,:r_gown_clean2,:e_qi,:r_gown_inv_up,:e_pickup_hospital,:r_gown_inv_down,:e_use,:r_gown_dirty]
}
