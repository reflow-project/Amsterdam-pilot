# this is a separate script to develop the fsm and flow for the chatbot script content in swapshop_en.json 
# it doesn't do anything with a database / uploading etc, it just does the chat flow
require 'json'
require 'telegram/bot'
require 'dotenv/load'
require 'byebug'

Dotenv.require_keys('TELEGRAM_TOKEN')
token = ENV['TELEGRAM_TOKEN']

# load the json definitions
file = File.read('swapshop_en.json')
questions = JSON.parse(file)

#set the current state (in memory)
current_state = :ping
telegram_id = 1726644084 #my telegram account

#get the question and answers for the current state
q_defs = questions[current_state.to_s] 
q_text = q_defs.first #should exist always
q_answers = q_defs[1..] # can be empty array

# create one time, inline keyboard if there are default answers
kb = q_answers.map{ |answer| [
  Telegram::Bot::Types::InlineKeyboardButton.new(text: answer, callback_data: answer)
]}
q_options = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb, one_time_keyboard: true)

Telegram::Bot::Client.run(token) do | bot |
  #send a message for the specific current state
  bot.api.send_message(chat_id: telegram_id, text: q_text, reply_markup: q_options)

  bot.listen do |message|
	case message
	when Telegram::Bot::Types::CallbackQuery
	  puts message.data # received one of the default answers
	  puts message.inspect
	  bot.api.edit_message_reply_markup(chat_id: message.message.chat.id, message_id: message.message.message_id, reply_markup: nil)
  	  bot.api.send_message(chat_id: telegram_id, text: "thanks for replying: #{message.data}")
	when Telegram::Bot::Types::Message
	  puts message.text # received a normal answer / message
	end
  end
end

# TODO define the fsm
# 4. listen for incoming messages and go through the script based on the fsm



# 5. test the flow
# 6. when all this is done, integrate the parts into the swapstories/lib/tasks/swapbot.rb script
