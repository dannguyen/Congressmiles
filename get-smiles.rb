####
# Coding tutorial: Congressmiles
# Optional part: Crop just the smiles and make a collage
#
# PREREQS: '200x250/' contains images and Face jsons
# See also: http://ruby.bastardsbook.com/chapters/image-manipulation/
#
require 'rubygems' 
require 'rmagick' # a Ruby wrapper for the awesome ImageMagick library
require 'crack'  # to do easy parsing of JSON


IMAGES_DIR = '200x250'
NYT_CONGRESS_JSON_NAME = 'nyt-congress.json'
S_DIR = "smiles"
Dir.mkdir(S_DIR) unless File.exists?(S_DIR)

ROWS = 5
COLS = 20

COMP_WIDTH = 800.0
COMP_RATIO = 4.0 / 5

SMILE_WIDTH = COMP_WIDTH / COLS
SMILE_HEIGHT = SMILE_WIDTH * COMP_RATIO

COMP_HEIGHT = SMILE_HEIGHT * ROWS


puts [SMILE_WIDTH,SMILE_HEIGHT].join('x')


senate_json = Crack::JSON.parse(File.open(NYT_CONGRESS_JSON_NAME, 'r').read)
senators = senate_json['results'][0]['members']

senators.each do |senator|
  puts "Cropping #{senator['id']} - #{senator['first_name']} #{senator['last_name']}"

  f_fname = File.join(IMAGES_DIR, "#{senator['id']}.json")
  fjson = Crack::JSON.parse(File.open(f_fname).read)['photos'][0]
  f = fjson['tags'].sort_by{|t| t['attributes']['face']['confidence']}.reverse[0]  

  senator['f_json'] = f 


  img_name = "#{senator['id']}.jpg"
  img = Magick::Image.read("#{IMAGES_DIR}/#{img_name}")[0]
  w = img.columns
  h = img.rows

  smile_width = w * (f['mouth_right']['x'] - f['mouth_left']['x'])/100.0 + 20
  smile_height = smile_width * COMP_RATIO
  
  img = img.crop(
    w * (f['mouth_left']['x'])/100.0 - 10, 
    h * (f['mouth_left']['y']-5)/100.0, 
    smile_width, 
    smile_height
  ).resize(SMILE_WIDTH,SMILE_HEIGHT)

  cname = "#{S_DIR}/#{img_name}"
  img.write(cname)  
  senator['smile_img'] = img

end

# sort out the senators by smile confidence, ratio of mouth width

senators = senators.sort_by do |senator|
  conf = senator['f_json']['attributes']['smiling']['confidence'] * (senator['f_json']['attributes']['smiling']['value'] =='true' ? 1 : -1)
  [conf,  (senator['f_json']['mouth_right']['x'] - senator['f_json']['mouth_left']['x']) / senator['f_json']['width']]
end.reverse


smile_img = Magick::Image.new(COMP_WIDTH,COMP_HEIGHT)  

COLS.times.each do |c|
  ROWS.times.each do |r|

    senator = senators[r * COLS + c]
    
    smile_img.composite!( senator['smile_img'],        
        c * SMILE_WIDTH, r * SMILE_HEIGHT, 
        Magick::OverCompositeOp)
  end
end

smile_img.write("all_smiles.jpg")

#
# CREDITS:
# by Dan Nguyen dan@danwin.com / twitter: @dancow / http://danwin.com
#
# APIs:
#   Sunlight Labs: http://services.sunlightlabs.com/docs/Sunlight_Congress_API/
#   NYT Congress API: http://developer.nytimes.com/docs/congress_api/
#   Face API: http://developers.face.com/
# 
# More programming help at:
# http://ruby.bastardsbook.com/chapters/image-manipulation/
# http://studio.imagemagick.org/RMagick/doc/
