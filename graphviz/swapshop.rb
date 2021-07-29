require_relative 'dsl.rb'
graph("Swapshop"){
  agent :a_consumer, "Consumer"
  agent :a_swapshop, "Swapshop"
  agent :a_sorter, "Sorting Company"
  agent :a_unraveler, "Unraveling Company"
  agent :a_incinerator, "Incinerator"
  agent :a_ti, "Textile Industry"
  agent :a_repairshop, "Repair Shop"

  resource :r_discarded, "Discarded Clothing (Vol)"
  resource :r_unsorted, "Unsorted Clothing (Vol)"
  resource :r_wearable1, "Wearable Clothing (Inv)" 
  resource :r_unwearable, "Depreciated Clothing (Vol)"
  resource :r_unsorted, "Unsorted material (Vol)"
  resource :r_waste1, "Waste (Vol)"
  resource :r_waste2, "Waste (Vol)"
  resource :r_recyclable, "Recycleable Material (Vol)"
  resource :r_recyclable2, "Recycleable Material (Vol)"
  resource :r_unraveled, "Unraveled material"
  resource :r_wearable2, "Wearable clothing (Vol)"

  # consumer brings in discarded items to swapshop
  event :e_swap_in, "Transfer (swap in)"
  event :e_sort_swapshop, "Consume / Produce (sorting)"
  role :e_swap_in, :a_swapshop, "Receiver"
  role :e_swap_in, :a_consumer, "Provider"
  
  flow [:r_discarded, :e_swap_in, :r_unsorted, :e_sort_swapshop] 
  # swapshop sorts incoming stuff
  role :e_sort_swapshop, :a_swapshop, "Operator"
 
  # swapshop puts in rack, most items are swapped out
  event :e_swap_out, "Transfer (swap out)"
  role :e_swap_out, :a_swapshop, "Provider"
  role :e_swap_out, :a_consumer, "Receiver"
  flow [:e_sort_swapshop, :r_wearable1, :e_swap_out, :r_wearable2] 

  # the citizen uses the wearable clothing
  role :e_wear, :a_consumer, "User"
  event :e_wear, "Use (wear)"
  flow [:r_wearable2, :e_wear, :r_wearable2]
 
  # the citizen maintains the wearable clothing
  role :e_care, :a_consumer, "Maintainer"
  event :e_care, "Modify (care/maintain)"
  flow [:r_wearable2, :e_care, :r_wearable2]
 
  # the citizen has a repairs shop fix some wearable clothing
  role :e_repair, :a_repairshop, "Operator"
  event :e_repair, "Modify (repair/refurb)"
  flow [:r_wearable2, :e_repair, :r_wearable2]

  # the citizen discards to trash
  event :e_cons_trash, "Transfer (trash)"
  role :e_cons_trash, :a_consumer, "Provider"
  role :e_cons_trash, :a_incinerator, "Receiver"
  flow [:r_wearable2, :e_cons_trash, :r_waste2]

  # the citizen discards to recycle bin
  event :e_cons_recycle, "Transfer (recycle)"
  role :e_cons_discard, :a_consumer, "Provider"
  role :e_cons_discard, :a_sorter, "Receiver"
  flow [:r_wearable2, :e_cons_recycle, :r_unsorted] 

  # the citizen brings in items to swap show (back to r_discarded) 
  event :e_cons_discard, "Transfer (discard)"
  flow [:r_wearable2, :e_cons_discard, :r_discarded]

  # swapshop sends unwearable stuff to sorting company
  event :e_depreciate, "Transfer (depreciate)"
  role :e_depreciate, :a_swapshop, "Provider"
  role :e_depreciate, :a_sorter, "Receiver"
  flow [:e_sort_swapshop, :r_unwearable, :e_depreciate, :r_unsorted, :e_sort_sc] 
  
  #sorting company deems some stuff is waste, which goes on to the incinerator
  event :e_incinerate, "Consume (incinerate)"
  event :e_sort_sc, "Consume / Produce (sorting)"
  event :e_discard_sc, "Transfer (discard)"
  role :e_sort_sc, :a_sorter, "Operator"
  role :e_discard_sc, :a_sorter, "Provider"
  role :e_discard_sc, :a_incinerator, "Receiver"
  role :e_incinerate, :a_incinerator, "Operator"
  flow [:e_sort_sc, :r_waste1, :e_discard_sc, :r_waste2, :e_incinerate]  

  #sorting company deems some stuff recycleable, which goes on to the unraveler, which unravels (recyclces), and sells to tghe textile industry
  event :e_recycle, "Consume / Produce (recycle)"
  event :e_unraveler_sell, "Transfer (sell)"
  event :e_sorter_sell, "Transfer (sell)"
  role :e_sorter_sell, :a_sorter, "Provider"
  role :e_sorter_sell, :a_unraveler, "Receiver"
  role :e_recycle, :a_sorter, "Operator"
  role :e_unraveler_sell, :a_unraveler, "Provider"
  role :e_unraveler_sell, :a_ti, "Receiver"
  flow [:e_sort_sc, :r_recyclable, :e_sorter_sell, :r_recyclable2, :e_recycle, :r_unraveled, :e_unraveler_sell ] 
  

}
