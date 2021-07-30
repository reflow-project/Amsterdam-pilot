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
  resource :r_jeans_use, "Jeans Lot (In use)" # in use jeans
  resource :r_jeans_disc, "Jeans Vol (Discarded)" # discarded jeans
  resource :r_cotton, "Cotton garments Vol (Sorted)" # sorted cotton garments
  resource :r_cotton_clean, "Cotton garments Vol (Clean)" # clean cotton garments
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
   
  # 2. atelier transfer to retail
  # 3. retail sells to consumer
  # 4. consumer in use (laundry, maintainance, repair events)
  # 4a. consumer trashes jeans to waste
  # 5. consumer transfer (discard) to sorter
  # 6. sorter sorts jeans to cotton
  # 7. sorter transfers cotton to cleaner
  # 8. cleaner transfers cotton to clipper
  # 8a. cleaner thrashes cotton to waste
  # 9. clipper transfers cotton to unraveler
  # 10. unraveler transfers (unraveled) cotton to preparator 
  # 11. preparator transfers denim fibers to spinner
  # 12. spinner produces cloth
  # 13. spinner transfers cloth to atelier (sell)
  # back to 1.

}
