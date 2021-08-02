require_relative 'dsl.rb'

graph("Zorgschorten") {

  #use cycle
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

  # 1. sorting and incineration flow
  agent :a_sorter, "Sorting Center"
  agent :a_incinerator, "Incinerator"
  
  resource :r_gown_dep, "Gown Lot (depreciated)"
  resource :r_unsorted, "Unsorted Material Vol (kg)"
  resource :r_waste, "Waste (Volume, kg)"

  # Tcs transfer depreciated gowns to sorting center
  event :e_transfer_sort, "Transfer (Delivery)"
  role :e_transfer_sort, :a_tsc, "Provider"
  role :e_transfer_sort, :a_sorter, "Receiver"

  # sorting senter sorts gowns to recylable material and waste
  event :e_sort, "Consume / Produce (Sort)"
  role :e_sort, :a_sorter, "Operator"

  # waste transfered to incinerator
  event :e_transfer_waste, "Transfer"
  role :e_transfer_waste, :a_sorter, "Provider"
  role :e_transfer_waste, :a_incinerator, "Receiver"
 
  # incinerator consumes waste
  event :e_incinerate, "Consume (Incinerate)"
  role :e_incinerate, :a_incinerator, "Operator"
  
  flow [:e_qi, :r_gown_dep, :e_transfer_sort, :r_unsorted, :e_sort, :r_waste, :e_transfer_waste, :r_waste, :e_incinerate]

  # 3. production flow
  
  # recyleable material is transferred from sorting center to unraveling agent
  # unraveling agent recycles to unraveled material
  # unraveled material is transfered to textile company
  # textile company produces textile from unraveled material
  # textile is transferred from textile company to confectie atelier
  # confectie atelier produces new gown lot
  # gown lot is sold to hospital
}
