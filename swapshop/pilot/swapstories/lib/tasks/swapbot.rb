# telegram bot for handling swaps
require 'telegram/bot'
require 'dotenv/load'
require 'byebug'
Dotenv.require_keys('TELEGRAM_TOKEN')

class SwapBot

  #we're in root state handling commands only
  def handle_commands(bot, agent, message)

    if(message.text.start_with? "/role #{ENV['ROLE_PW']}")
      agent.toggle_role!
      bot.api.send_message(chat_id: message.chat.id, text: "role: #{agent.agent_type}")
    end 

    if(message.text.start_with? "/swap ")
      tracking_id = message.text[6..-1]

      #TODO check if presented with valid id / validation code
      if(true)
        puts "creating new resource"
        #put resource in the database
        res = Resource.create(title: 'Nader in te vullen',
                              description: 'nader in te vullen',
                              image_url: nil,
                              tracking_id: tracking_id,
                              shop_id: nil,
                              ros_id: nil,
                              owner: agent.id)


        Story.create(resource_id: res.id,
                     content: "Still empty")

        #determine the type of event, and create the event
        #TODO move this to when the questions are complete finalise the event
        Event.create(event_type: SwapEvent::SWAP_OUT, 
                     source_agent_id: 1, 
                     target_agent_id: 3, 
                     resource_id: res.id, 
                     location: "Amsterdam")

        #update the state
        if(agent.agent_type == AgentType::PARTICIPANT)
          agent.fsm.swap
        else
          agent.fsm.register
        end

        #bot.api.send_message(chat_id: message.chat.id, text: "je bent nu de eigenaar van #{tracking_id}!")
        handle_dialog(bot, agent, message)
      end
    end
  end

  #we're in some other state than root
  def handle_dialog(bot, agent, message)
    bot.api.send_message(chat_id: message.chat.id, text: "current state: #{agent.dialog_state}")
    agent.fsm.next
  end

  def listen 
    token = ENV['TELEGRAM_TOKEN']
    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        agent = Agent.find_or_create_by_telegram_id(message.chat.id)
        puts agent.dialog_state
        case agent.dialog_state.to_sym
        when :root
          handle_commands(bot, agent, message)
        else
          handle_dialog(bot, agent, message)
        end
      end
    end
  end
end
