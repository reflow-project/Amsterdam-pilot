# telegram bot for handling swaps
require 'telegram/bot'
require 'dotenv/load'
require 'byebug'
Dotenv.require_keys('TELEGRAM_TOKEN')

SKU_REGEX = %r{\ARP(?<nr>\d\d\d\d\d)\Z}
class SwapBot

  # TODO validation code that is generated at seed time
  def is_valid?(tracking_id)
      valid_id = false
      if tracking_id.match(SKU_REGEX)
        tracking_nr = tracking_id.match(SKU_REGEX)[:nr].to_i 
        valid_id = tracking_nr > 0 and tracking_nr <= 2500
      end
      valid_id
  end

  #we're in root state handling commands only
  def handle_commands(bot, agent, message)

    if(message.text.start_with? "/role #{ENV['ROLE_PW']}")
      agent.toggle_role!
      bot.api.send_message(chat_id: message.chat.id, text: "role: #{agent.agent_type}")
    end 

    if(message.text.start_with? "/swap ")
      tracking_id = message.text[6..-1]

      if(is_valid? tracking_id)
        res = Resource.find_by tracking_id: tracking_id

        if(res == nil)
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
          # Event.create(event_type: SwapEvent::SWAP_OUT, 
          #              source_agent_id: 1, 
          #              target_agent_id: 3, 
          #              resource_id: res.id, 
          #              location: "Amsterdam")
        end

        # if it already exists check ownership, if different 
        # update the owner to the current agent
        if(res.owner == agent.id)
          #basically error message, we stay in root state
          bot.api.send_message(chat_id: message.chat.id, text: "je bent al eigenaar van #{tracking_id}!")
        else # update the chat state for followup
          if(agent.agent_type == AgentType::PARTICIPANT)
            agent.fsm.swap
          else #swap shop
            agent.fsm.register
          end
          send_dialog(bot, agent, message)
        end
      else #invalid id
        bot.api.send_message(chat_id: message.chat.id, text: "dit is een ongeldig tracking id. Heb je misschien een typfout gemaakt?")
      end
    end
  end

  def receive_dialog(bot,agent,message)
    puts message.text
    send_dialog(bot,agent,message)
  end

  #we're in some other state than root
  def send_dialog(bot, agent, message)
    #TODO handle answer based on what state we're in 
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
          receive_dialog(bot, agent, message)
        end
      end
    end
  end
end
