require_relative 'lightspeed_client.rb'
require_relative 'reflow_os_client.rb'

# 1. get new total from lightspeed client
retail_client = LightSpeedClient.new
retail_client.extract()
retail_client.removeCoupons()
total = retail_client.getOverallInventoryLevel
puts "\ntotal: #{total}"

# show some debug info
retail_client.showStatistics()
retail_client.showTopTen()

# current number used for debugging
# total = 1000 
puts "new total: #{total}"

# 2. get current total from reflow os client
ros_client = ReflowOSClient.new
me = ros_client.me
puts me.email
prev_total =  ros_client.getInventoryLevel()
puts "previous total: #{prev_total}"

# 3. update current total using a raise or lower
if total == prev_total
  # do nothing
elsif total > prev_total
  delta = total - prev_total 
  puts "raise by #{delta}"
  result = ros_client.updateInventoryLevel(delta,true)
  puts result
else
  delta = prev_total - total 
  puts "lower by #{delta}"
  ros_client.updateInventoryLevel(delta,false)
  puts result 
end

updated_total = ros_client.getInventoryLevel()
puts "updated total: #{updated_total}"
