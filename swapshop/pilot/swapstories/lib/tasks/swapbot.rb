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

  def do_swap_shop_registration_flow(tracking_id, bot, agent, message)
    res = Resource.create(title: 'Nader in te vullen',
                          description: 'nader in te vullen',
                          image_url: nil,
                          tracking_id: tracking_id,
                          shop_id: nil,
                          ros_id: nil,
                          owner: agent.id)

    Story.create(resource_id: res.id,
                 content: "Still empty")
    agent.dialog_subject = res.id 
    agent.fsm.register
    send_dialog(bot, agent, message) #kick off registration questions
  end

  #we're in root state handling commands only
  def handle_commands(bot, agent, message)

    if(message.text.start_with? "/role #{ENV['ROLE_PW']}")
      agent.toggle_role!
      bot.api.send_message(chat_id: message.chat.id, text: "role: #{agent.agent_type}")
    end 

    if(message.text.start_with? "/swap ")
      tracking_id = message.text[6..-1]

      if not is_valid? tracking_id
        bot.api.send_message(chat_id: message.chat.id, text: "dit is een ongeldig tracking id. Heb je misschien een typfout gemaakt?")
        return
      end

      res = Resource.find_by tracking_id: tracking_id
      if(res != nil and res.owner == agent.id)
        bot.api.send_message(chat_id: message.chat.id, text: "je bent al eigenaar van #{tracking_id}!")
        return
      end
     
      if(agent.agent_type == AgentType::SWAPSHOP)
        if(res == nil)
          do_swap_shop_registration_flow(tracking_id, bot, agent, message)
          #TODO create born event
        else
          prev_owner = res.owner
          #TODO create swap_in event
          res.owner = agent.id
          res.save!
          bot.api.send_message(chat_id: message.chat.id, text: "#{tracking_id} is weer terug bij de swapshop!")
        end
      end

      if(agent.agent_type == AgentType::PARTICIPANT)
        if(res == nil)
          bot.api.send_message(chat_id: message.chat.id, text: "dit tracking id is onbekend. Heb je misschien een typfout gemaakt?")
        else
          prev_owner = res.owner
          #TODO create swap_out event if prev owner was the swap shop
          res.owner = agent.id
          res.save!
          agent.dialog_subject = res.id
          agent.fsm.swap
          send_dialog(bot, agent, message) #kick off follow  up questions
        end
      end
    end
  end

          #determine the type of event, and create the event
          #TODO move this to when the questions are complete finalise the event
          # Event.create(event_type: SwapEvent::SWAP_OUT, 
          #              source_agent_id: 1, 
          #              target_agent_id: 3, 
          #              resource_id: res.id, 
          #              location: "Amsterdam")
  
  def receive_dialog(bot,agent,message)
    puts "received answer for #{agent.dialog_state} -> #{message.text} regarding #{agent.dialog_subject}"
    res = Resource.find(agent.dialog_subject) 
    
    case agent.dialog_state.to_sym
    when :r_title
      #update the title but for what resource? 
      puts "updating title for resource #{agent.dialog_subject}"
      res.title = message.text
      res.save!
    when :r_description
      puts "updating description for resource #{agent.dialog_subject}"
      res.description = message.text
      res.save!
    when :r_photo
      puts "updating photo for resource #{agent.dialog_subject}"
      res.image_url = message.text
      res.save!
      #TODO change this to check for a real photo, 
      #which we can download and save in the public uploads folder and save a reference to that url
    else
      puts "unhandled dialog: #{agent.dialog_state}"
    end

    if(true) # TODO determine if we like this answer enough to pose the next question
      agent.fsm.next
      send_dialog(bot,agent,message)
    end
  end

  #we're in some other state than root
  def send_dialog(bot, agent, message)
    bot.api.send_message(chat_id: message.chat.id, text: "current state: #{agent.dialog_state}")
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
