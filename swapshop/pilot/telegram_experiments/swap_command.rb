require 'telegram/bot'
require 'dotenv/load'
Dotenv.require_keys('TELEGRAM_TOKEN')
token = ENV['TELEGRAM_TOKEN']

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    if(message.text.start_with? "/swap ")
      tracking_id = message.text[6..-1]
      bot.api.send_message(chat_id: message.chat.id, text: "je bent nu de eigenaar van #{tracking_id}!")
    end
  end
end
