# telegram bot for handling swaps
require 'telegram/bot'
require 'dotenv/load'
Dotenv.require_keys('TELEGRAM_TOKEN')
token = ENV['TELEGRAM_TOKEN']

desc "telegram swapbot"
namespace :swapbot do
  task :run => :environment do
    res = Resource.find(1)
    puts "hi #{res}!"
    puts token

    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        if(message.text.start_with? "/swap ")
          tracking_id = message.text[6..-1]
          puts "register resource #{tracking_id}"
          #TODO check if valid id
          #TODO if valid; search or create agent
          #put resource in the database
          #TODO set found/created agent as owner
          res = Resource.create(title: 'Nader in te vullen',
                description: 'nader in te vullen',
                image_url: nil,
                tracking_id: tracking_id,
                shop_id: nil,
                ros_id: nil)
          bot.api.send_message(chat_id: message.chat.id, text: "je bent nu de eigenaar van #{tracking_id}!")

          Story.create(resource_id: res.id,
             content: "Still empty")
         
          #determine the type of event, and create the event
          Event.create(event_type: SwapEvent::SWAP_OUT, 
             source_agent_id: 1, 
             target_agent_id: 3, 
             resource_id: res.id, 
             location: "Amsterdam")
        end
      end
    end
  end
end
