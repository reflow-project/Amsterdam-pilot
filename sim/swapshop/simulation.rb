require_relative '../dsl.rb'
require 'securerandom'

# Simple scenario
# Day 1
# We have one customer who has 5 garments in their closet
# Takes them to the swapshop, who inspects the garments
# 4 of them make it to the rack, 1 is transferred to wieland as waste (garment consumed, waste produced) 
# 3 other pieces of garment that are already in the rack are taken from the rack by the consumer, puts them in his closet (transfer)
# Day 2
# the consumer wears one of the new garments in his closet (use)
# Day 3
# the consumer repairs one of the new garments in his closet (transfer-custody by consumer to rep+ modify by repairshop)
# One day after repair, the garment comes back to the consumer (transfer-custody rep back to consumer)
#
simulation("Swapshop Use Cycle", Date.today, Date.today + 1) do

  #declare units used in this simulation
  unit :u_kg, "kg", "kg"
  unit :u_piece, "om2:one", "#"

  $rid = 0
  resource :garment, "Garment", :u_piece do
    $rid += 1 
    # this id is not the reflow os id, but the id used by cleanlease to track the invidual gown
    garment_types = %w(jeans t-shirt blouse skirt jacket bag socks tanktop shoes shorts)
    garment_materials = %w(cotton leather woollen synthetic)
    garment_colors = %w(blue red yellow black colorful camo polkadot green purple tiedye)
    description = "#{garment_colors.sample} #{garment_materials.sample} #{garment_types.sample}"
    {
     :tracking_id => "http://reflow.the-swapshop.com/id/#{$rid}", 
     :description => description 
    }
  end

  resource :waste, "Waste", :u_kg do
    {
      :description => "Assorted garment waste"
    }
  end

  agent :a_swapshop, "Swapshop" do
    location 52.38305176049192, 4.886653427044765,
	 	"Haarlemmerdijk 89, 1013 KC Amsterdam",
		"The Swap Shop",
		"We doen ook herstelwerk"
    inventory :rack, "rack", :garment, 10
    pool :discarded, "waste", :garment, 0
  end

  agent :a_consumer, "Participant" do
    location 52.372914232734466, 4.900383569253214,
	 	"Nieuwmarkt 4, 1012 CR Amsterdam",
		"Consumer woont hier",
		"In een kasteel"    
    pool :closet, "closet", :garment, 5
  end

  agent :a_wieland, "Wieland" do
    location 52.51345006821827, 4.7785117343772345,
	 	"Handelsweg 8, 1521 NH Wormerveer",
		"Wieland Textiles",
		"wieland.nl"    
    pool :waste_container, "waste container 1", :waste , 0
    #because this pool is of type wasste, it has a volume unit so we can create only one 'wallet' resource that we can reuse
  end

  agent :a_repairshop, "Repairshop" do
    location 52.38305176049192, 4.886653427044765,
	 	"Haarlemmerdijk 89, 1013 KC Amsterdam",
		"Miss Fixit Repair",
		"Herstelwerk"
  end

  #day 1
  event :swap, "consumer swaps items" do 
    schedule cron: 1 
    process do 

      #consumer takes in 5 garments
      as_performer :a_consumer
      pool_take :closet 
      transfer_batch :a_swapshop, "swap in"
     
      #swapshop performs qi
      as_performer :a_swapshop
      pass_batch (2.0 / 5)

      #passed items go into the rack
      inventory_put :rack

      #failed qi items are put in the discarded pool, for later transfer by wieland
      failed_take 
      pool_put :discarded

      #consumer takes 3 new garments in exchange
      inventory_take :rack, 3
      transfer_batch :a_consumer, "swap out"
      pool_put :closet
    end
  end  

  event :recycle, "recycle discarded garments" do
    schedule cron: 7
    process do
      as_performer :a_swapshop
      pool_take :discarded
      transform_batch_to_volume :waste, 0.2  #could model this with a raise instead of a produce too? discuss
      transfer_volume :a_wieland, "recycle" #could specify a named resource for the receiver? discuss, 
      #TODO transfer_batch should just check to see if the batch contains a volume resource instead of using transfer_volume here
      pool_put :waste_container #TODO this should be a volume pool, by checking the resource specification of :waste
    end
  end

  event :repair, "repair a garment" do
    schedule cron: 1
    process do
      as_performer :a_consumer
      pool_take :closet, 1
      #transfer_custody_batch :a_repairshop, "to repair" #can't do transfer custody, because we can't do a repair then
      transfer_batch :a_repairshop, "to repair"

      as_performer :a_repairshop
      modify_batch "refitting buttons"

      #transfer_custody_batch :a_consumer, "fixed" #can't do this because of reflow os implementation issue
      transfer_batch :a_consumer, "fixed"
      as_performer :a_consumer
      use_batch "wearing my fixed stuff, i look great"
      pool_put :closet
    end
  end
 
end
