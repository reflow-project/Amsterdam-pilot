require 'chunky_png'
require 'quirc'
count = 0
Dir.glob("qrcodes/*.png") do |file|
       result = `zbarimg -q #{file}` 
       count += 1 if not result.empty? 
       `open #{file}` if result.empty?
       puts "#{file}: #{result}"
end
puts count
