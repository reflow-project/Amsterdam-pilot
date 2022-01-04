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

  #for now we don't implement the quizzes yet

  #participant swap new item branch
  event :swap, :root => :s_q1
  event :next, :s_q1 => :s_q2
  event :next, :s_q2 => :s_q_photo
  event :next, :s_q_photo => :root

  on_enter do |event|
	target.dialog_state = event.to
	puts "changed dialog state to #{event.to}"
  end
end

agent.fsm = fsm
agent.fsm.branch_new #immediately go to the new branch for testing

def receive_dialog(bot, agent, message)
	agent.fsm.next #for now just do next everytime
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
	  puts message.data # received one of the default answers
	when Telegram::Bot::Types::Message
	  puts message.text # received a normal answer / message
	end
	receive_dialog(bot,agent,message)
  end
end

# 5. test the flow
# 6. when all this is done, integrate the parts into the swapstories/lib/tasks/swapbot.rb script
