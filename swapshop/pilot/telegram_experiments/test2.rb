require 'telegram/bot'
require 'dotenv/load'
Dotenv.require_keys('TELEGRAM_TOKEN')
token = ENV['TELEGRAM_TOKEN']

# create state per user (question number)
# if state doesn't exist initialize the state => b.v. 0 = intro...
state = 0

intro = "Hello dit is de bot, you will get two questions;\n say /start to start over or /stop to stop, zeg Okay om te beginnen met de eerste vraag"
intro_options = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(Okay)], one_time_keyboard: true)
 
question1 = 'Hoeveel nieuwe kleding koop jij per maand?'
question1= 'In welk jaar dit gekocht?'
answers1 = Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: [%w(0-1 1-3), %w(meer)], one_time_keyboard: true)
question2 = 'Hoeveel preloved tweedehands)  kleding koop jij per maand?'
question2 = 'En in welke maand heb je dit gekocht?'
answers2 = Telegram::Bot::Types::ReplyKeyboardMarkup

answers_year = Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: [ %w(2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022), "Before 2012", "I don't remember"], one_time_keyboard: true)
answers_month = Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: [ %w(jan feb mar apr may jun jul aug sep oct nov dec),"I don't remember"], one_time_keyboard: true)

goodbye = "dank je wel!"

Telegram::Bot::Client.run(token) do |bot|
bot.listen do |message|
  case message.text
    # See more: https://core.telegram.org/bots/api#replykeyboardmarkup
  when '/start'
        state = 0
        bot.api.send_message(chat_id: message.chat.id, text: intro, reply_markup: intro_options)
  when '/stop'
    # See more: https://core.telegram.org/bots/api#replykeyboardremove
    kb = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    bot.api.send_message(chat_id: message.chat.id, text: 'Sorry to see you go :(', reply_markup: kb)
  else
    puts "received answer #{message.text} for state #{state}"
    if(state == 0)
      if(message.text == "Okay")
          bot.api.send_message(chat_id: message.chat.id, text: question1, reply_markup: answers_year)
          state = 2
      end
    elsif(state == 2)
      bot.api.send_message(chat_id: message.chat.id, text: question2, reply_markup: answers_month)
      state = 3
    elsif(state == 3)
      bot.api.send_message(chat_id: message.chat.id, text: goodbye)
      state = 4
    end
  end
end
end
