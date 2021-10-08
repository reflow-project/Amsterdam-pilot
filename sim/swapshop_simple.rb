require_relative 'dsl.rb'

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
simulation("Swapshop Use Cycle", Date.today, Date.today + 30) do
  $rid = 0
  resource :garment, "Garment" do
    $rid += 1 
    # this id is not the reflow os id, but the id used by cleanlease to track the invidual gown
    garment_types = %w(jeans t-shirt blouse skirt jacket bag socks tanktop shoes shorts)
    garment_materials = %w(cotton leather woollen synthetic)
    garment_colors = %w(blue red yellow black colorful camo polkadot green purple tiedye)
    description = "#{garment_colors.sample} #{garment_materials.sample} #{garment_types.sample}"
    {:tracking_id => "http://reflow.the-swapshop.com/id/#{$rid}", :description => description }
  end

  agent :swapshop, "Swapshop Amsterdam" do
    authenticate "SWAPSHOP_EMAIL", "SWAPSHOP_PASSWORD"
    location "SWAPSHOP_LOCATION"
    inventory :rack, "rack", :garment, 10
  end

  agent :consumer, "Sir Swapsalot" do
    authenticate "CONS1_EMAIL", "CONS1_PASSWORD"
    location "CONS1_LOCATION"
    pool :closet, "closet", :garment, 5
  end

  agent :repairshop, "Miss Fixit" do
    authenticate "REPAIRSHOP_EMAIL", "REPAIRSHOP_PASSWORD"
    location "REPAIRSHOP_LOCATION"
  end

  # TODO agent consumer 1-30  (would be great to script somehow)
  # i will start with one consumer for simplicity
  # pseudo code for events
 
  # event consumer_swap_in
  # as consumer
  # pool_take :closet 1-5 
  # transfer_batch consumer swapshop
  
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


