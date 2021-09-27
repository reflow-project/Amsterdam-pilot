require_relative 'dsl.rb'

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
    pool :garments, "fresh supply", :garment, 2
  end

  #todo agent consumer 1-30  (would be great to script somehow)
  
  # pseudo code for events
  
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
  # etc.

  # event consumer_swap
  # as consumer
  # pool_take :closet 1-5 
  # transfer_batch consumer swapshop
  
  #etc
end


