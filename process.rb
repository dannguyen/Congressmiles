####
# Coding tutorial: Congressmiles
# PART 2: Processing
#   a. Crop each Senator's mugshot using Face.com metadata and RMagick
#   b. Create a webpage ranking faces by smile, glasses, mood, and androgenicity 
#



require 'rubygems' 
require 'rmagick' # a Ruby wrapper for the awesome ImageMagick library
require 'crack'  # to do easy parsing of JSON

## Step A: Crop photos
##    - Read Senator data (NYT API) and face meta-data (Face.com API) 
##      from JSON files downloaded in PART 1 (fetch.rb)
##    - Crop files using RMagick and save

## PREREQS: Images and meta-data stored in a folder called '200x250'
IMAGES_DIR = '200x250'
NYT_CONGRESS_JSON_NAME = 'nyt-congress.json'


CROP_DIR = "crop"
Dir.mkdir(CROP_DIR) unless File.exists?(CROP_DIR)

senate_json = Crack::JSON.parse(File.open(NYT_CONGRESS_JSON_NAME, 'r').read)
senators = senate_json['results'][0]['members']


senators.each do |senator|
  puts "Cropping #{senator['id']} - #{senator['first_name']} #{senator['last_name']}"
  
  
## Face.com's API returns an array of photos with an array of tags
  face_fname = File.join(IMAGES_DIR, "#{senator['id']}.json")

  ## Since each JSON response we got has just one photo, we use index 0  
  fjson = Crack::JSON.parse(File.open(face_fname).read)['photos'][0]
  
  ## But there may be more than one face tagged...so let's pick the most prominent
  f = fjson['tags'].sort_by{|t| t['attributes']['face']['confidence']}.reverse[0]  

  # adding to the senator hash for later reference...
  senator['face_json'] = f 
  
  
  
  
## Now open image with RMagick
  
  img_name = "#{senator['id']}.jpg"
  img = Magick::Image.read("#{IMAGES_DIR}/#{img_name}")[0]
  w = img.columns
  h = img.rows
  
## let's crop to the specified face center,height,and width attributes
## http://studio.imagemagick.org/RMagick/doc/image1.html#crop
  
  # First, let's get the crop rectangle using the face-API data
  ## Face.com API returns the relative point (i.e. from 0-100) of a feature, 
  ## not exact pixels

  ## assuming the face_width, face_height gets only the face and not all of the head
  ## let's add a threshold on all sides (i.e. 5% and 15% to width and height respectively)...
  ## but be careful that neither face_height, face_width are greater than 100.0:
    
  face_center = f['center']
  face_height = [f['height'] + 15.0, 100.0 ].min
  face_width  = [f['width'] + 5.0, 100.0 ].min
  

  
  img.crop!(
    w * (face_center['x']-face_width/2)/100.0, 
    h * (face_center['y']-face_height/2)/100.0, # y-coord of top-left corner
    w * face_width/100.0,
    h * face_height/100.0
  )
  
  
  
  # my mind has blanked out on why I can't crop this to something like 90x120. Oh well
  img = img.resize_to_fit(120) 
  
  cname = "#{CROP_DIR}/#{img_name}"
  img.write(cname)
  
  # add some convenience attributes
  senator['crop_image'] = cname
  senator['name_title'] = "Sen. #{senator['last_name']} (#{senator['party']}-#{senator['state']})"
  
end



## Step B: Let's make a webpage
# This is just messy HTML construction

## define a div/img printing helper function

def foo_div_img(sen, *val)
  # takes in an block that passes in a senator hash
  h =<<IMG
  <div class="face"><img src="#{sen['crop_image']}" alt="#{sen['name_title']}"/><div class="name">#{sen['name_title']} #{"#{val}" if val}</div></div>
IMG
end

html_fname = "smiles.html"
html_file = File.open(html_fname, 'w')

html_file.puts("<html><body>")


## Best smile
# remember how we added to each senator hash a 'face_json' attribute?

senators = senators.sort_by{ |s|     
    [ 
      s['face_json']['attributes']['smiling']['confidence'], 
      s['face_json']['mouth_right']['x'] - s['face_json']['mouth_left']['x'] 
    ]
  }.reverse
  
smiles =  senators.select{|s| 
       s['face_json']['attributes']['smiling']['value']=='true'}  
  
puts "#{smiles.length} senators had a smile"
  
html_file.puts("<h2>10 Biggest Smiles</h2>")
smiles[0..9].each do |senator|
  html_file << foo_div_img(senator, senator['face_json']['attributes']['smiling']['confidence'])
end


html_file.puts("<h2>10 Most Ambiguous Smiles</h2>")
smiles.reverse[0..9].each do |senator|
  html_file << foo_div_img(senator, senator['face_json']['attributes']['smiling']['confidence'])
end


html_file.puts("<h2>The Non-Smilers</h2>")
# these had a smiling value of 'false'...the higher the confidence, the
# more non-smiley the face

non_smiles = (senators-smiles)
non_smiles.each do |senator|
  html_file << foo_div_img(senator,  senator['face_json']['attributes']['smiling']['confidence'])
end


##s Now for some partisanship
html_file.puts("<h2>Smiles by party</h2>")

html_file.puts("
<table><thead><tr><th>Party</th><th>Smiles</th><th>Non-smiles</th><th>Avg. Smile Confidence</th></tr></thead>
<tbody>")

['D','R','I'].each do |party|
  
  party_smilers = smiles.select{|sen| sen['party']==party}
  html_file.puts( "<tr>" + [party, 
      party_smilers.length, 
      non_smiles.select{|sen| sen['party']==party}.length,
      party_smilers.inject(0){|sm, sen| sm += sen['face_json']['attributes']['smiling']['confidence']} / party_smilers.length
    ].map{|v| "<td>#{v}</td>"}.join(' ') + "</tr>")
    
end

html_file.puts("</tbody></table>")


## Let's have fun with the 'glasses' attribute

## same strategy as before
glasses = senators.select{|s| 
    s['face_json']['attributes']['glasses']['value']=='true'}.sort_by{ |s|     
      s['face_json']['attributes']['glasses']['confidence']
  }.reverse
  
puts "#{glasses.length} senators wear glasses"
html_file.puts("<h2>10 Most Bespectacled Senators</h2>")
glasses[0..9].each do |senator|
  html_file << foo_div_img(senator, senator['face_json']['attributes']['glasses']['confidence'])
end





## One more rating: Face.com API's gender confidence

# first sort by confidence, regardless of gender
sens = senators.select{|s|  g = s['face_json']['attributes']['gender'] }.sort_by{|s| 
    s['face_json']['attributes']['gender']['confidence']
  }.reverse
    
males = sens.select{|s|  s['face_json']['attributes']['gender']['value']=='male'}
    
females = sens.select{|s|  s['face_json']['attributes']['gender']['value']=='female'}
    
puts "Face.com thinks there are #{males.length} men and #{females.length} women in the Senate"

html_file.puts("<h2>10 Most Masculine-Featured Senators</h2>")
males[0..9].each do |senator|
  html_file << foo_div_img(senator, senator['face_json']['attributes']['gender']['confidence'])
end


html_file.puts("<h2>10 Most Feminine-Featured Senators</h2>")
females[0..9].each do |senator|
  html_file << foo_div_img(senator,senator['face_json']['attributes']['gender']['confidence'])
end
    



## End the file
html_file.puts("</body></html>")
html_file.close



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



