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

    if(message.text.start_with? "/start ")
      puts message.text
      tracking_id = message.text[7..-1]
      puts tracking_id

      if not is_valid? tracking_id
        bot.api.send_message(chat_id: message.chat.id, text: "dit is een ongeldig tracking id. Heb je misschien een typfout gemaakt?")
        return
      end

      res = Resource.find_by tracking_id: tracking_id
      if(res != nil and res.owner == agent.id)
        bot.api.send_message(chat_id: message.chat.id, text: "je bent al eigenaar van #{tracking_id}!")
        return
      end

      #/swap performed by swapshop, either new or swap in
      if(agent.agent_type == AgentType::SWAPSHOP)
        if(res == nil)
          do_swap_shop_registration_flow(tracking_id, bot, agent, message)
        else
          prev_owner_id = res.owner
          Event.create(event_type: SwapEvent::SWAP_IN, 
                       source_agent_id: prev_owner_id, 
                       target_agent_id: agent.id, 
                       resource_id: res.id, 
                       location: "Amsterdam")

          res.owner = agent.id
          res.save!
          bot.api.send_message(chat_id: message.chat.id, text: "#{tracking_id} is weer terug bij de swapshop!")
        end
      end

      #/swap performed by participant, either with the swap shop or with a friend
      if(agent.agent_type == AgentType::PARTICIPANT)
        if(res == nil)
          bot.api.send_message(chat_id: message.chat.id, text: "dit tracking id is onbekend. Heb je misschien een typfout gemaakt?")
        else
          
          #depending on if it's a swap between shop and participant or between two participants we register a different event type
          prev_agent = Agent.find(res.owner)
          event_type = (prev_agent.agent_type == AgentType::PARTICIPANT) ? SwapEvent::SWAP : SwapEvent::SWAP_OUT
          Event.create(event_type: event_type, 
                       source_agent_id: prev_agent.id, 
                       target_agent_id: agent.id, 
                       resource_id: res.id, 
                       location: "Amsterdam")

          res.owner = agent.id
          res.save!
          agent.dialog_subject = res.id
          agent.fsm.swap
          send_dialog(bot, agent, message) #kick off follow  up questions
        end
      end
    end
  end
            
  def receive_dialog(bot,agent,message)
    puts "received answer for #{agent.dialog_state} -> #{message.text} regarding #{agent.dialog_subject}"
    res = Resource.find(agent.dialog_subject) 
   
    valid_answer = false

    case agent.dialog_state.to_sym
    when :r_title
      #update the title but for what resource? 
      puts "updating title for resource #{agent.dialog_subject}"
      res.title = message.text
      res.save!
      valid_answer = true
    when :r_description
      puts "updating description for resource #{agent.dialog_subject}"
      res.description = message.text
      res.save!
      valid_answer = true
    when :r_photo
      puts "updating photo for resource #{agent.dialog_subject}"

      #for now we just show the image from telegram, no need to save, wonder how long it stays on server though?
      url = image_url(bot,message,agent.dialog_subject) 
      if(url)
        res.image_url = url 
        res.save!
       
        #we have everything so ready to be born in reflow os
        Event.create(event_type: SwapEvent::BORN, 
                       source_agent_id: agent.id, 
                       target_agent_id: agent.id, 
                       resource_id: res.id, 
                       location: "Amsterdam")
        
        valid_answer = true
      end
    when :s_q1, :s_q2
      Transcript.create(resource_id: res.id,
                        agent_id: agent.id,
                        dialog_key: agent.dialog_state,
                        dialog_value: message.text)
      valid_answer = true
    when :s_q_photo
      url = image_url(bot,message,res.id) 
      if(url)
        Transcript.create(resource_id: res.id,
                        agent_id: agent.id,
                        dialog_key: agent.dialog_state,
                        dialog_value: url)
        valid_answer = true
      end
    else
      puts "unhandled dialog: #{agent.dialog_state}"
    end
    
    if(valid_answer) 
      agent.fsm.next
      send_dialog(bot,agent,message)
    end
  end

  #download a foto and return url
  def image_url(bot, message, subject_id)
    token = ENV['TELEGRAM_TOKEN']
    if message.photo.count > 0

      #download the photo from telegram
      photo_id = message.photo.last.file_id
      foto = bot.api.get_file(file_id: photo_id)  #get the file meta data
      path = foto["result"]["file_path"]
      telegram_url = "https://api.telegram.org/file/bot#{token}/#{path}"  
      `curl #{telegram_url} > public/uploads/#{subject_id}.jpg`
      "/uploads/#{subject_id}.jpg" 
    end
  end

  def send_dialog(bot, agent, message)
    #all these keys correspond to the fsm states defined in the agent model
    questions = {
      :r_title => "Wat is de titel van dit item?",
      :r_description => "Hoe zou je het item omschrijven?",
      :r_photo => "Kun je een foto van het item opsturen?",
      :s_q1 => "Vraag 1: Waarom heb je dit item gekozen?",
      :s_q2 => "Vraag 2: Wanneer denk je dat je het zult dragen?",
      :s_q_photo => "Kun je een foto van het item opsturen?",
      :root => "Bedankt voor het meedoen! Geef een /swap commando om te beginnen met een nieuw kledingstuk."
    }
    question = questions[agent.dialog_state.to_sym]
    bot.api.send_message(chat_id: message.chat.id, text: question)
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
