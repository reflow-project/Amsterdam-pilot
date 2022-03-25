require_relative 'dsl.rb'

graph("Maison_et_Objet") {

  #use cycle
  sub_graph("Maison et Objet") do 
  
    agent :a_organizer, "Event organizer"
    agent :a_recovery, "Recovery centre (storage)"
    agent :a_craft, "Makers"
  
    resource :r_tempconstrorg, "Temp construction @event"
    resource :r_tempconstrmkr, "Temp construction @maker"
    resource :r_newobject, "New object from scrappings"
    resource :r_woodscrev, "Wood scrapping @event"
    resource :r_woodscrcnt, "Wood scrapping @centre"
    resource :r_woodscrcra, "Wood scrapping @maker"

    
    event :e_producescr, "Produce"
    event :e_transfercentre, "Transfer"
    event :e_transfermaker, "Transfer"
    event :e_transferorg, "Transfer"

    role :e_producescr, :a_organizer, "provider"
    role :e_producescr, :a_organizer, "receiver"
    role :e_transfercentre, :a_organizer, "provider"
    role :e_transfercentre, :a_recovery, "receiver"
    role :e_transfermaker, :a_recovery, "provider"
    role :e_transfermaker, :a_craft, "receiver"
    role :e_transferorg, :a_craft, "provider"
    role :e_transferorg, :a_organizer, "receiver"
    role :e_produceobj, :a_craft, "provider"
    
    
    flow [:e_produceobj,:r_tempconstrmkr,:e_transferorg,:r_tempconstrorg,:e_producescr,:r_woodscrev,:e_transfercentre,:r_woodscrcnt,:e_transfermaker,:r_woodscrcra]
  end
  
  sub_graph("Digitalisation") do 
  
    agent :a_dimensionuse, "Dimension-use"
  
    resource :r_resrecord, "Resource record"

    event :e_produceresrecord, "Produce"
    
    role :e_produceresrecord, :a_dimensionuse, "provider"
    role :e_produceresrecord, :a_dimensionuse, "receiver"
    
    flow [:r_woodscrcnt,:e_produceresrecord,:r_resrecord]
  end

  sub_graph("New Objects") do
    
    event :e_produceobj, "Produce"
    
    role :e_produceobj, :a_craft, "provider"
    role :e_produceobj, :a_craft, "receiver"    
    
    flow [:r_woodscrcra,:e_produceobj,:r_newobject]
  end

}
