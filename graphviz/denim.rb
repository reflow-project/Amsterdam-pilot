require_relative 'dsl.rb'

graph("Denim"){
  agent :a_spinner, "Spinner"
  agent :a_preparator, "Spinning Preparator"
  agent :a_atelier, "Confection Company"
  agent :a_retail, "Retail"
  agent :a_consumer, "Consumer"
  agent :a_sorter, "Sorting Company"
  agent :a_cleaning, "Cleaning Company"
  agent :a_unraveler, "Unraveling Company"
  agent :a_incinerator, "Incinerator"

  resource :r_denim_cloth, "Denim Vol" # ready for jeans production
  resource :r_denim_cloth_waste, "Denim Vol"# production waste 
  resource :r_jeans_new, "Jeans Lot (New)" # fresh jeans
  resource :r_jeans_retail, "Jeans Inv (in rack)" # jeans in shop
  resource :r_jeans_use, "Jeans Lot (In use)" # in use jeans
  resource :r_jeans_disc, "Jeans Vol (Discarded)" # discarded jeans
  resource :r_cotton, "Cotton garments Vol (Sorted)" # sorted cotton garments
  resource :r_cotton_clean, "Cotton garments Vol (Clean)" # clean cotton garments
  resource :r_cleaning_waste, "Waste (Cleaning)" # clean cotton garments
  resource :r_cotton_clipped, "Cotton Vol (Clipped)" # clipped cotton garments
  resource :r_cotton_unraveled, "Cotton Vol (Unraveled)"
  resource :r_spinning_fibers, "Spinning Fiber"
  resource :r_cellulose, "Cellulose" # added by spinner to unraveled cotton to make spinning fibers
  resource :r_waste, "Waste"

  # flow:
  # 1. atelier produces jeans from cloth
  event :e_create, "Produce"
  role :e_create, :a_atelier, "Operator"
  flow [:r_denim_cloth, :e_create, :r_jeans_new]
  
  # 1a. atelier transfers cloth production waste to unraveler
  event :e_recycle_atelier, "Transfer (production waste)"
  role :e_recycle_atelier, :a_atelier, "Provider"
  role :e_recycle_atelier, :a_unraveler, "Receiver"
  flow [:e_create, :r_denim_cloth_waste, :e_recycle_atelier]
   
  # 2. atelier transfer jeans to retail
  event :e_sell_atelier, "Transfer (sell)"
  role :e_sell_atelier, :a_atelier, "Provider"
  role :e_sell_atelier, :a_retail, "Receiver"
  flow [:r_jeans_new, :e_sell_atelier, :r_jeans_retail]

  # 3. retail sells to consumer
  event :e_sell_retail, "Transfer (sell)"
  role :e_sell_retail, :a_retail, "Provider"
  role :e_sell_retail, :a_consumer, "Receiver"
  flow [:r_jeans_retail, :e_sell_retail, :r_jeans_use]

  # 4. consumer in use (laundry, maintainance, repair events)
  event :e_use, "Use (laundry, maint, rep)"
  role :e_use, :a_consumer, "User"
  flow [:r_jeans_use, :e_use, :r_jeans_use]

  # 4a. consumer trashes jeans to waste
  event :e_trash_cons, "Transfer (trash)"
  role :e_trash_cons, :a_consumer, "Provider"
  role :e_trash_cons, :a_incinerator, "Receiver"
  event :e_incinerate, "Consume (incinerate)"
  role :e_incinerate, :a_incinerator, "Operator"
  flow [:r_jeans_use, :e_trash_cons, :r_waste, :e_incinerate]

  # 5. consumer transfer (discards) to sorter
  event :e_discard_cons, "Transfer (discard)"
  role :e_discard_cons, :a_consumer, "Provider"
  role :e_discard_cons, :a_sorter, "Receiver"
  flow [:r_jeans_use, :e_discard_cons, :r_jeans_disc]

  # 6. sorter sorts jeans to cotton
  event :e_sort, "Consume/Produce (sort)"
  role :e_sort, :a_sorter, "Operator"
  flow [:r_jeans_disc, :e_sort, :r_cotton]

  # 7. sorter transfers (sells?) cotton to cleaner, which cleans AND clips
  event :e_sell_sorter, "Transfer (sell)"
  role :e_sell_sorter, :a_sorter, "Provider"
  role :e_sell_sorter, :a_cleaning, "Receiver"
  event :e_clean, "Modify (clean)"
  role :e_clean, :a_cleaning, "Operator"
  event :e_clip, "Modify (clip)"
  role :e_clip, :a_cleaning, "Operator"
  flow [:r_cotton, :e_sell_sorter, :r_cotton, :e_clean, :r_cotton_clean , :e_clip, :r_cotton_clipped]
  
  # 8a. cleaner thrashes cotton to waste
  event :e_trash_clean, "Transfer (trash)"
  role :e_trash_clean, :a_cleaning, "Provider"
  role :e_trash_clean, :a_incinerator, "Receiver"
  flow [:e_clean, :r_cleaning_waste, :e_trash_clean, :r_waste]

  # 9. clipper transfers cotton to unraveler, which unravels
  event :e_sell_cleaner, "Transfer (sell)"
  role :e_sell_cleaner, :a_cleaning, "Provider"
  role :e_sell_cleaner, :a_unraveler, "Receiver"
  event :e_unravel, "Consume / Produce (unravel)"
  role :e_unravel, :a_unraveler, "Operator"
  flow [:r_cotton_clipped, :e_sell_cleaner, :r_cotton_clipped, :e_unravel, :r_cotton_unraveled]
  # also it unravels production waste
  flow [:e_recycle_atelier, :r_cotton_clipped]


  # 10. unraveler transfers (unraveled) cotton to preparator, which prepares
  event :e_sell_unraveler, "Transfer (sell)"
  role :e_sell_unraveler, :a_unraveler, "Provider"
  role :e_sell_unraveler, :a_preparator, "Receiver"
  event :e_prepare, "Consume / Produce (prepare)"
  role :e_prepare, :a_preparator, "Operator"
  flow [:r_cellulose, :e_prepare]
  flow [:r_cotton_unraveled, :e_sell_unraveler, :r_cotton_unraveled, :e_prepare, :r_spinning_fibers]

  # 11. preparator transfers denim fibers to spinner, which produces cloth, and sells it to atelier
  event :e_sell_prep, "Transfer (sell)"
  role :e_sell_prep, :a_preparator, "Provider"
  role :e_sell_prep, :a_spinner, "Receiver"
  event :e_spin, "Consume / Produce (spin)"
  role :e_spin, :a_spinner, "Operator"
  event :e_sell_spin, "Transfer (sell)"
  role :e_sell_spin, :a_spinner, "Provider"
  role :e_sell_spin, :a_atelier, "Receiver"
  flow [:r_spinning_fibers, :e_sell_prep, :r_spinning_fibers, :e_spin, :r_denim_cloth, :e_sell_spin, :r_denim_cloth]
  
  #loop closed

}
