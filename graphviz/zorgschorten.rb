require_relative 'dsl.rb'

graph("Zorgschorten") {
# rfid tagging of new gowns to monitor use cycles and recycle rates

  #use cycle
  sub_graph("Use Cycle") do 
    agent :a_hospital, "Hospital"
    #OLVG

    agent :a_laundry, "Laundry Service"
    #Clean lease

    agent :a_tsc, "Textile Service Company"
    #Clean lease
    
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
    role :e_pickup_tcs, :a_tsc, "receiver"
    role :e_pickup_tcs, :a_laundry, "provider"
    role :e_qi, :a_tsc, "inspector"
    role :e_pickup_hospital, :a_tsc, "provider"
    role :e_pickup_hospital, :a_hospital, "receiver"
    role :e_use, :a_hospital, "user"

    flow [:r_gown_dirty,:e_pickup,:r_gown_dirty2,:e_work,:r_gown_clean,:e_pickup_tcs,:r_gown_clean2,:e_qi,:r_gown_inv_up,:e_pickup_hospital,:r_gown_inv_down,:e_use,:r_gown_dirty]
  end

  sub_graph("Sorting and Incineration") do
    # 1. sorting and incineration flow
    
    agent :a_sorter, "Sorting Center"
    # Wieland

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
  end

  # 3. production flow
  sub_graph("Production flow") do
   
    agent :a_unraveler, "Unraveling Agent"
    # Frankenhuis / Wieland
   
    # Manufacturing: will occur in AMS by new producer
    agent :a_tc, "Textile Company"
    agent :a_atelier, "Confectie Atelier"

    resource :r_material, "Recycleable Material Vol (kg)"
    resource :r_unraveled, "Unraveled Material Vol (kg)"
    resource :r_textile, "Textile Vol (kg)"
    resource :r_gown_new, "Gown Lot (new)"

    # recyleable material is transferred from sorting center to unraveling agent
    event :e_transfer_unrav, "Transfer"
    role :e_transfer_unrav, :a_sorter, "Provider"
    role :e_transfer_unrav, :a_unraveler, "Receiver"

    # unraveling agent recycles to unraveled material
    event :e_unravel, "Consume & Produce (Unravel)"
    role :e_unravel, :a_unraveler, "Operator"

    # unraveled material is transfered to textile company
    event :e_transfer_tc, "Transfer"
    role :e_transfer_tc, :a_unraveler, "Provider"
    role :e_transfer_tc, :a_tc, "Receiver"

    # textile company produces textile from unraveled material
    event :e_recycle, "Consume / Produce (Recycle)"
    role :e_recycle, :a_tc, "Operator"

    # textile is transferred from textile company to confectie atelier
    event :e_transfer_atelier, "Transfer"
    role :e_transfer_atelier, :a_tc, "Provider"
    role :e_transfer_atelier, :a_atelier, "Receiver"

    # confectie atelier produces new gown lot
    event :e_manufacture, "Consume / Produce (Manufacture)"
    role :e_manufacture, :a_atelier, "Operator"

    # gown lot is sold to tsc
    event :e_transfer_hos, "Transfer (sell)"
    role :e_transfer_hos, :a_atelier, "Provider"
    role :e_transfer_hos, :a_tsc, "Receiver"

    flow [:e_sort, :r_material, :e_transfer_unrav, :r_material, :e_unravel, :r_unraveled, :e_transfer_tc, :r_unraveled, :e_recycle, :r_textile, :e_transfer_atelier, :r_textile, :e_manufacture, :r_gown_new, :e_transfer_hos, :r_gown_inv_up]
  end
}
