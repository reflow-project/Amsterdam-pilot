require 'chunky_png'
require 'quirc'

count = 0
Dir.glob("qrcodes/*.png") do |file|
    img = ChunkyPNG::Image.from_file(file)
    res = Quirc.decode(img).first
    count += 1 if res
    puts res.payload  if res
end
puts count
