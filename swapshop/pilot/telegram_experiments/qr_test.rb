require 'telegram/bot'
require 'net/http'
require 'json'
require 'zbar'
require 'byebug'
require 'dotenv/load'
Dotenv.require_keys('TELEGRAM_TOKEN')
token = ENV['TELEGRAM_TOKEN']

Telegram::Bot::Client.run(token) do |bot|

  bot.listen do |message|
    if message.photo.count > 0

	  #download the photo from telegram
	  photo_id = message.photo.last.file_id
	  foto = bot.api.get_file(file_id: photo_id)  #get the file meta data
	  path = foto["result"]["file_path"]
      `curl https://api.telegram.org/file/bot#{token}/#{path} > qrcode.jpg`   
		
	  #analyse the qr code
      scan = `zbarimg -q qrcode.jpg`
      scan = "no qr code found, please type the RPXXXX code by hand" if scan.empty? 
      
      #send scan result
      bot.api.send_message(chat_id: message.chat.id, text: scan)
	end

  end 
end
