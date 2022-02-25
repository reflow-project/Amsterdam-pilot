# telegram bot for handling swaps
require 'telegram/bot'
require 'dotenv/load'
Dotenv.require_keys('TELEGRAM_TOKEN')

SKU_REGEX = %r{\ARP(?<nr>\d\d\d\d\d)\Z}
class SwapBot

  #these are the chatbot definitions, available via class variable
  @@questions = JSON.parse(File.read('swapshop_en.json'))

  def is_valid?(tracking_id)
      valid_id = false
      if tracking_id.match(SKU_REGEX)
        tracking_nr = tracking_id.match(SKU_REGEX)[:nr].to_i 
        valid_id = tracking_nr > 0 and tracking_nr <= 2500
      end
      valid_id
  end

  # update the resource 
  # the agent is currently chatting about
  def birth_resource_for(agent)
	res = Resource.find(agent.dialog_subject) 
	answers = res.transcripts.map { |t| [t.dialog_key, t.dialog_value]}.to_h
	res.title =	"%s" % [answers[:new_kind.to_s]]
	res.description = "%s %s %s %s %s" % [
	  answers[:new_kind.to_s],
	  answers[:new_model.to_s],
	  answers[:new_color.to_s],
	  answers[:new_size.to_s],
	  answers[:new_brand.to_s]
	] 
	res.save!
	Event.create(event_type: SwapEvent::BORN, 
				 source_agent_id: agent.id, 
				 target_agent_id: agent.id, 
				 resource_id: res.id, 
				 location: "Amsterdam")
  end

  # publish the photo for the resource 
  # the agent is currently chatting about
  def publish_photo_for(agent)
	res = Resource.find(agent.dialog_subject) 
	answers = res.transcripts.map { |t| [t.dialog_key, t.dialog_value]}.to_h
	res.image_url = answers[:new_photo.to_s] 	
	res.save!
  end

  #receive a default answer
  def receive_button(bot, agent, button)
    case button
    when "SWAP"
      agent.fsm.branch_swap
    when "WEAR"
      agent.fsm.branch_wear
    when "CARE"
      agent.fsm.branch_care
    when "OTHER"
      agent.fsm.branch_other
    when "REPAIRED"
      agent.fsm.branch_repaired
    when "ADJUSTED"
      agent.fsm.branch_adjusted
    when "CANCEL"
      agent.fsm.cancel
    when "YES" #answering yes always does next
      if (agent.dialog_state == :new_summary.to_s) #if the summary is correct, create the details and the born event
   			birth_resource_for(agent) 	        
      elsif(agent.dialog_state == :new_publish.to_s)
			publish_photo_for(agent)
      end
      if(agent.dialog_state == :wear_share.to_s)
        Event.create(event_type: SwapEvent::USE, 
                     source_agent_id: agent.id, 
                     target_agent_id: agent.id, 
                     resource_id: agent.dialog_subject, 
                     location:nil)
      end
      agent.fsm.next
    when "NO"
      agent.fsm.no
    else
      # received one of the default answers
      Transcript.create(resource_id: agent.dialog_subject,
                      agent_id: agent.id,
                      dialog_key: agent.dialog_state,
                      dialog_value: button)
      agent.fsm.next #for now just do next everytime
    end
    send_dialog(bot,agent)
  end

  def receive_dialog(bot,agent,message)
    puts "received answer for #{agent.dialog_state} -> #{message.text} regarding #{agent.dialog_subject}"
    begin
      res = Resource.find(agent.dialog_subject)
    rescue => e
      puts "Exception: #{e}"
      return
    end

    value = message.text

    #save url to downloaded photo in :new_photo state as transcript value
    if(agent.dialog_state == :new_photo.to_s)
      url = image_url(bot,agent,message) 
      value = url if url != nil
    end

    Transcript.create(resource_id: res.id,
                      agent_id: agent.id,
                      dialog_key: agent.dialog_state,
                      dialog_value: value)


    agent.fsm.next
    send_dialog(bot,agent)

    #create events when at the end of the dialog branches
    if(agent.dialog_state == :swap_end.to_s)
      prev_agent = Agent.find(res.owner)
      event_type = SwapEvent::SWAP
     
      #mark special cases where the swapshop is involved
      if(prev_agent.agent_type == AgentType::PARTICIPANT && agent.agent_type == AgentType::SWAPSHOP)
        event_type = SwapEvent::SWAP_IN
      end

      if(prev_agent.agent_type == AgentType::SWAPSHOP && agent.agent_type == AgentType::PARTICIPANT)
        event_type = SwapEvent::SWAP_OUT
      end

      Event.create(event_type: event_type, 
                   source_agent_id: prev_agent.id, 
                   target_agent_id: agent.id, 
                   resource_id: res.id, 
                   location: nil)
      
      # update the resource to reflect the new owner
      res.owner = agent.id
      res.save!
    end

    
    if(agent.dialog_state == :care_adjusted_end.to_s)
      Event.create(event_type: SwapEvent::ADJUST, 
				 source_agent_id: agent.id, 
				 target_agent_id: agent.id, 
				 resource_id: res.id, 
				 location:nil)

    end
    
    if(agent.dialog_state == :care_repaired_end.to_s)
      Event.create(event_type: SwapEvent::REPAIR, 
				 source_agent_id: agent.id, 
				 target_agent_id: agent.id, 
				 resource_id: res.id, 
				 location:nil)
    end

  end

  #download a foto and return url
  def image_url(bot, agent, message)
    token = ENV['TELEGRAM_TOKEN']
    if message.photo.count > 0

      #download the photo from telegram
      subject_id = agent.dialog_subject
      photo_id = message.photo.last.file_id
      foto = bot.api.get_file(file_id: photo_id)  #get the file meta data
      path = foto["result"]["file_path"]
      telegram_url = "https://api.telegram.org/file/bot#{token}/#{path}"  
      `curl #{telegram_url} > public/uploads/#{agent.id}_#{subject_id}.jpg`
      "/uploads/#{agent.id}_#{subject_id}.jpg" 
    end
  end

  def send_dialog(bot, agent)
    q_defs = @@questions[agent.dialog_state.to_s] 
    q_text = q_defs.first #should exist always
    q_answers = q_defs[1..] # can be empty array

      
    # create one time, inline keyboard if there are default answers
    kb = q_answers.map{ |answer| 
      Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
    }

    q_options = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb, one_time_keyboard: true)
 
    if(agent.dialog_state == :new_date_year.to_s)
      row1 = %w(2013 2014 2015 2016 2017).map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }
      row2 = %w(2018 2019 2020 2021 2022).map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }
      row3 = ["2012 or earlier","I can't remember"].map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }
      q_options = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [ row1, row2, row3], one_time_keyboard: true)
    end
 
    if(agent.dialog_state == :new_date_month.to_s)
      row1 = %w(Jan Feb Mar Apr).map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }
      row2 = %w(May Jun Jul Aug).map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }
      row3 = ["Sep","Oct", "Nov", "Dec"].map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }
      row4 = ["I can't remember"].map{ |answer| 
        Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
      }

      q_options = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [ row1, row2, row3, row4 ], one_time_keyboard: true)
    end
 
    # expand summary template
    if(agent.dialog_state == :new_summary.to_s)
      q_text = create_summary(q_text, agent.dialog_subject) 
    end

    bot.api.send_message(chat_id: agent.telegram_id, text: q_text, reply_markup: q_options)
  end

  def create_summary(template, resource_id)
    res = Resource.find(resource_id)
    answers = res.transcripts.map { |t| [t.dialog_key, t.dialog_value]}.to_h
    template % [
      answers[:new_kind.to_s],
      answers[:new_model.to_s],
      answers[:new_color.to_s],
      answers[:new_size.to_s],
      answers[:new_brand.to_s]
    ] 
  end

  def handle_start(bot, agent, message)
    tracking_id = message.text[7..-1]
    if not is_valid? tracking_id
      bot.api.send_message(chat_id: message.chat.id, text: "invalid tracking id!")
      return
    end
  
    #since we only get the tracking id at start, we need to always save 
    #it as subject of the current conversatino
    res = Resource.find_by tracking_id: tracking_id
    if res == nil      
      #in case someone types a non existing id (shouldn't happen when you go through the site)
      bot.api.send_message(chat_id: message.chat.id, text: "invalid tracking id!")
      return
    end

	agent.dialog_state = :start.to_s #also needed for reset
	agent.fsm.restore!(:start) #reset the machine at start command	
    agent.dialog_subject = res.id 
    agent.save!

    #always send the start dialog to mark the beginning of a fresh chat
    send_dialog(bot,agent)

    if(res != nil and res.owner == nil) 
      #set the current agent as owner if it has none, and kick off the new branch
	  agent.fsm.branch_new 
      res.owner = agent.id
      res.save!
    elsif(res != nil and res.owner != nil) 
	  agent.fsm.branch_main #if the resource is already owned, kick of th main branch
    end
    send_dialog(bot,agent)
  end

  def listen 
    token = ENV['TELEGRAM_TOKEN']

    while true     
      begin
        Telegram::Bot::Client.run(token) do |bot|
          bot.listen do |message|
           
            begin
              case message
              when Telegram::Bot::Types::CallbackQuery
                agent = Agent.find_or_create_by_telegram_id(message.message.chat.id)
                begin
                  bot.api.edit_message_reply_markup(chat_id: message.message.chat.id, message_id: message.message.message_id, reply_markup: nil) #clear the inline options
                rescue Telegram::Bot::Exceptions::ResponseError 
                  puts "clearing error not fatal"
                end
                receive_button(bot,agent,message.data) #handle the callback
              when Telegram::Bot::Types::Message
                puts "received: #{message.text}"
                agent = Agent.find_or_create_by_telegram_id(message.chat.id)
                if(message.text != nil and message.text.start_with? "/start ")
                  handle_start(bot, agent, message)
                elsif(message.text != nil and message.text.start_with? "/role #{ENV['ROLE_PW']}")
                  agent.toggle_role!
                  bot.api.send_message(chat_id: message.chat.id, text: "role: #{agent.agent_type}")
                else 
                  receive_dialog(bot, agent, message) #handle a normal text message
                end
              end
            end
          rescue => e
            # we want to handle all individual message errors before the outer loop, 
            # otherwise the message will stay in the telegram queue and the error will repeat forever
            puts "Exception handling message: #{e}"
            puts e.backtrace
          end
        end
      rescue => e
        # errors in the outer loop have to do with connectivity, let's just try to connect again in 5 seconds
        puts "Exception in run loop: #{e}"
        puts e.backtrace
        sleep 5
      end
    end
  end
end
