require 'telegram_bot'
require 'dotenv/load'
Dotenv.require_keys('TELEGRAM_TOKEN')
bot = TelegramBot.new(token: ENV['TELEGRAM_TOKEN'])

puts bot

channel = TelegramBot::Channel.new(id: 1726644084)
message = TelegramBot::OutMessage.new
message.chat = channel
message.text = 'just wanted to send you something'
message.send_with(bot)

bot.get_updates(fail_silently: true) do |message|
  puts message.inspect
  puts "@#{message.from.first_name}: #{message.text}"

  command = message.get_command_for(bot)

  message.reply do |reply|
    case command
    when /greet/i
      reply.text = "Hello, #{message.from.first_name}!"
    else
      reply.text = "#{message.from.first_name}, have no idea what #{command.inspect} means."
    end
    puts "sending #{reply.text.inspect} to @#{message.from.first_name}"
    reply.send_with(bot)
  end
end
