require_relative 'dsl.rb'
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
  $rid = 0
  resource :garment, "Garment" do
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

  resource :waste, "Waste" do
    {
      :description => "Assorted garment waste",
      :unit => ENV["UNIT_KG"] 
    }
  end

  agent :a_swapshop, "Swapshop Amsterdam" do
    authenticate "SWAPSHOP_EMAIL", "SWAPSHOP_PASSWORD"
    location "SWAPSHOP_LOCATION"
    inventory :rack, "rack", :garment, 10
    pool :discarded, "waste", :garment, 0
  end

  agent :a_consumer, "Sir Swapsalot" do
    authenticate "CONS1_EMAIL", "CONS1_PASSWORD"
    location "CONS1_LOCATION"
    pool :closet, "closet", :garment, 5
  end

  agent :a_wieland, "Wieland" do
    authenticate "WIE_EMAIL", "WIE_PASSWORD"
    location "WIE_LOCATION"
    pool :waste_container, "waste container 1", :waste , 0
    #because this pool is of type wasste, it has a volume unit so we can create only one 'wallet' resource that we can reuse
  end

  agent :a_repairshop, "Miss Fixit" do
    authenticate "REPAIRSHOP_EMAIL", "REPAIRSHOP_PASSWORD"
    location "REPAIRSHOP_LOCATION"
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
      transform_batch_to_volume :waste, 0.2  #could do this with a raise instead of a produce too
      transfer_volume :a_wieland, "recycle"
      pool_put :waste_container
    end
  end

  # event swap_inspect
  # cron 1
  # as_performer a_swapshop
  # take_garments
  # pass_batch .5
  # put_inventory
  # transfer_fail a_swapshop a_wieland 

  # event swap_out
  # cron 1 (todo: but not on mondays and tuesdays)
  # as_performer a_swapshop
  # inventory_take 1-5
  # transfer_batch a_swapshop <random_consumer>
  # as_performer <random_consumer>
  # pool_put :closet

  # event wear
  # cron 0.5 #two random consumers wear a trackable garment each day?
  # as_performer <random_consumer>
  # pool_take :closet 1
  # use_batch "wear"

  # event repair
  # cron 4
  #  as_performer <random_consumer>
  # pool_take :closet 1
  # transfer_custody a_<random_consumer> a_repairshop
  # pool_put :in_repair

  # event repair_done
  # on_event repair with_delay 1-5
  # pool_take
  # batch_transfer consumer
 
end


