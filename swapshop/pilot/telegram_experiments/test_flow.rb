# this is a separate script to develop the fsm and flow for the chatbot script content in swapshop_en.json 
# it doesn't do anything with a database / uploading etc, it just does the chat flow
require 'json'
require 'telegram/bot'
require 'dotenv/load'
require 'byebug'
require 'finite_machine'

class Agent
	attr_accessor :dialog_state, :telegram_id, :fsm
end

#hardcoded agent
agent = Agent.new 
agent.telegram_id = 1726644084 #my telegram account

Dotenv.require_keys('TELEGRAM_TOKEN')
token = ENV['TELEGRAM_TOKEN']

# load the json definitions
file = File.read('swapshop_en.json')
$questions = JSON.parse(file)


fsm ||= FiniteMachine.new(agent) do

  #todo show intro on start, and then main (two messages)
  initial :start

  # todo determine automatically 
  # if an item is new item, then we go automatically in new branch
  event :branch_new, :start => :new_kind
  event :branch_main, :start => :main
 
  #main option branches
  event :branch_care, :main => :care_intro
  event :branch_other, :main => :other_intro
  event :branch_wear, :main => :wear_intro
  event :branch_swap, :main => :swap_intro
 
  # the care branches
  event :branch_adjusted, :care_intro => :care_adjusted
  event :branch_repaired, :care_intro => :care_repaired
  event :cancel, :care_intro => :main

  # the care adjusted sub branch 
  event :next,
        :care_adjusted => :care_adjusted_reason,
        :care_adjusted_reason => :care_adjusted_end,
        :care_adjusted_end => :main
  
  # the care repaired sub branch 
  event :next,
        :care_repaired => :care_repaired_end,
        :care_repaired_end => :main

  # the other branch happy flow
  event :next, 
        :other_intro => :other_share,
        :other_share => :other_share_yes,
        :other_share_yes => :main,
        :other_share_no => :main

  # other branch unhappy flow
  event :no, 
        :other_share => :other_share_no

  # the wear branch happy flow
  event :next,
        :wear_intro => :wear_occasion,
        :wear_occasion => :wear_share,
        :wear_share => :wear_share_confirmation,
        :wear_share_confirmation => :main

  # wear branch unhappy flow
  event :no, 
        :wear_intro => :main, # basically a cancel
        :wear_share => :main # we save it but don't share it

  # swap branch flow
  event :next, 
        :swap_intro => :swap_date,
        :swap_date => :swap_origin,
        :swap_origin => :swap_reason,
        :swap_reason => :swap_end,
        :swap_end => :main

  #the 'new' branch happy flow (18 questions)
  event :next, 
		:new_kind => :new_model,
  		:new_model => :new_color,
  		:new_color => :new_size,
		:new_size => :new_brand,
		:new_brand => :new_material,
		:new_material => :new_extra,
		:new_extra => :new_summary,
		:new_summary => :new_memory, #yes equals next in this case
		:new_memory => :new_date,
		:new_date => :new_usage,
		:new_usage => :new_last,
		:new_last => :new_reason,
		:new_reason => :new_pm,
		:new_pm => :new_photo,
		:new_photo => :new_publish, #yes equals next in this case
		:new_publish => :new_confirmation,
		:new_confirmation => :new_end,
		:new_end => :main #and we're back

  #the 'new' branch exceptions
  event :no, 
		:new_summary => :new_kind, #start over
		:new_publish => :new_end,#skip the publishing part
		:new_photo => :new_end #skip the photo part

  #TODO for now we don't implement the quizzes yet, comes at a later stage

  on_enter do |event|
	target.dialog_state = event.to
	puts "changed dialog state to #{event.to}"
  end
end

agent.fsm = fsm
#agent.fsm.branch_new #immediately go to this branch for testing
agent.fsm.branch_main #immediately go to this branch for testing

def receive_dialog(bot, agent, message)
	puts message.text # received a normal answer / message
	agent.fsm.next #for now just do next everytime
    send_dialog(bot,agent)
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
          agent.fsm.next
      when "NO"
          agent.fsm.no
      else
        # received one of the default answers
	    puts "unhandled button: #{button}"
        # probably persist as a default answer
        agent.fsm.next #for now just do next everytime
      end
      send_dialog(bot,agent)
end

def send_dialog(bot, agent)
  q_defs = $questions[agent.dialog_state.to_s] 
  q_text = q_defs.first #should exist always
  q_answers = q_defs[1..] # can be empty array

  # create one time, inline keyboard if there are default answers
  kb = q_answers.map{ |answer| 
	Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
  }
  q_options = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb, one_time_keyboard: true)
  bot.api.send_message(chat_id: agent.telegram_id, text: q_text, reply_markup: q_options)
end

Telegram::Bot::Client.run(token) do |bot|
  send_dialog(bot,agent)
  bot.listen do |message|
	case message
	when Telegram::Bot::Types::CallbackQuery
	  #clear the options
	  bot.api.edit_message_reply_markup(chat_id: message.message.chat.id, message_id: message.message.message_id, reply_markup: nil)
      receive_button(bot,agent,message.data)
	when Telegram::Bot::Types::Message
	  receive_dialog(bot,agent,message)
	end
  end
end

# 5. test the flow
# 6. when all this is done, integrate the parts into the swapstories/lib/tasks/swapbot.rb script
