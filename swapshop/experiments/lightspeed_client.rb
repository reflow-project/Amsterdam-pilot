# client for lightspeed retail API
# read secrets from .env 
require 'dotenv/load'
require 'rest-client'
require 'json'

Dotenv.require_keys("CLIENT_ID", "CLIENT_SECRET", "ACCESS_TOKEN", "REFRESH_TOKEN")

# connect to oauth see; https://developers.lightspeedhq.com/retail/authentication/authentication-overview/ 
# To request a temporary token (in the browser) use curl
class LightSpeedClient
  ACCOUNT_ID = 233246 #amsterdam swap shop, found in web application source code

  def initialize 
    # try to get a new token by refreshing, if the old one is still active we get it back anyway
    begin
      @access_token = ENV['ACCESS_TOKEN']
      @refresh_token = ENV['REFRESH_TOKEN'] # refresh tokens do not expire, if you use it at least once every 30 days!
      @inventory= []

      response = RestClient.post "https://cloud.lightspeedapp.com/oauth/access_token.php", 
        { grant_type: 'refresh_token', 
          refresh_token: @refresh_token, 
          client_id: ENV['CLIENT_ID'], 
          client_secret: ENV['CLIENT_SECRET']}, 
      {"Content-Type": 'application/x-www-form-urlencoded'}

      payload = JSON.parse(response)
      @access_token = payload["access_token"]

    rescue RestClient::ExceptionWithResponse => err
      puts err.response
    end
  end

  ## transform an inventory page to pick only the minimal info 
  def transform(page)
    items = page["Item"].select{|item|item != nil}
    items.map{ |item|
      shopInfo = item["ItemShops"]["ItemShop"].select{|shop| shop["shopID"] == "0"}.first 
      {
        :id => item["itemID"], 
        :description => item["description"],
        :inventory_level => shopInfo["qoh"].to_i
      }
    }
  end

  # remove coupons from the inventory
  def removeCoupons
    @inventory = @inventory.select{ |item| #remove all items that don't have inventory, or have 'swap' in the description
      (item[:description].include?("swap") == false)
    }
  end

  # print the first 10 items sorted by inventory level
  def showTopTen
    result = @inventory.sort { |a,b| 
      b[:inventory_level] <=> a[:inventory_level] # sort result by most qoh
    }

    puts ("top 10 #{DateTime.now}\n\n")
    head = result.take(10) 
    head.each do |item|
      puts "#{item[:inventory_level]} (#{item[:description]} ##{item[:id]})"
    end

  end

  def getOverallInventoryLevel
    @inventory.map{|item| item[:inventory_level]}.reduce(:+) 
  end

  def showStatistics
    puts "\n\n"
    total = getOverallInventoryLevel
    puts "number of unique id's in db: #{@inventory.count}"
    puts "total number of unique items in stock: #{@inventory.select{|item|item[:inventory_level] == 0}.count}"
    puts "total number of id's with more than one piece in stock: #{@inventory.select{|item|item[:inventory_level] > 1}.count}"
    puts "total number of pieces in stock: #{total}"
  end

  ## get an inventory page, parse and put minimal info items in the inventory array 
  def extract(lastItemID = nil)
    print(".")
    uri = "https://api.lightspeedapp.com/API/Account/#{ACCOUNT_ID}/Item.json?load_relations=%5B%22ItemShops%22%5D&orderby=itemID&limit=100"
    uri += "&itemID=%3E%2C#{lastItemID}" if(lastItemID != nil)
    response = RestClient.get uri, {authorization: "Bearer #{@access_token}", accept: "application/json"} 
    page = JSON.parse(response)
    count = page["@attributes"]["count"].to_i
    lastItemID = page["Item"].last["itemID"].to_i

    items = transform(page)
    @inventory += items 

    if(count > 100 && lastItemID != nil)
      sleep 1.5 # rate limit
      extract(lastItemID)
    end 

  end

end
