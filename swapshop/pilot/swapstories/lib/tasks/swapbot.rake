# telegram bot for handling swaps
require_relative 'swapbot.rb'

desc "telegram swapbot"
namespace :swapbot do
  task :run => :environment do
        SwapBot.new.listen              
  end
end
