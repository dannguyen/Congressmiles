####
# Coding tutorial: Congressmiles
# PART 1: Fetching
#   a. Download a zip file of images from Sunlight Labs and unzip it
#   b. Use NYT's Congress API to get latest list of Senators
#   c. Use Face.com API to download face-coordinates as JSON
#
# ...PART 2: Will cover how to use RMagick to crop the faces and make a webpage

require 'rubygems'
require 'restclient'  # to do easy HTTP requests / https://github.com/archiloque/rest-client
require 'crack'  # to do easy parsing of JSON

## 
## I have a JSON file called "~/.secrets.json" that has my secret keys:
# {
#  'face'=>'0758f76c33s1df8c1eecba44,151fff90644171f298edcb888',
#  'nyt'=>'bk1z8f698bajfkeqz66d534c5cb9c111:14:3023233'
# }
#
#

KEYS = Crack::JSON.parse(open(File.expand_path('~/.secrets.json')).read)
# KEYS will be a parsed into a hash similar to:
#  {'nyt'=>'AKSDFJLASDJF', 'face'=>'alksdjflaskdklsadfj'}
#

CONGRESS_NUMBER = 112

URLS = {
  'face'=>'http://api.face.com/faces/detect.json',
  'nyt'=>"http://api.nytimes.com/svc/politics/v3/us/legislative/congress/#{CONGRESS_NUMBER}/senate/members.json?api-key=#{KEYS['nyt']}",
  'sunlight'=>'http://assets.sunlightfoundation.com/moc/200x250.zip'
}


## Step A. Download a zip file of images from Sunlight:

zip_basename = File.basename(URLS['sunlight'], '.zip')

unless File.directory?(zip_basename)
  puts "Downloading #{URLS['sunlight']}...this may take awhile..."
  File.open("#{zip_basename}.zip", 'w'){|f| f.write( RestClient.get(URLS['sunlight']) ) }

## Use the backtick to call your systems' unzip program...hopefully you have 
## 'unzip' somewhere. Otherwise, unzip the folder manually and just skip this step:

  `unzip #{zip_basename}.zip`
  
## a directory named [zip_basename] should appear in your working directory
## this contains all the image files
end

puts "Number of images in #{zip_basename}: " + Dir.glob("#{zip_basename}/*.jpg").length.to_s


## Step B. Download JSON of current U.S. senators from NYT API

nyt_congress_json_name = 'nyt-congress.json'

unless File.exists?(nyt_congress_json_name)
  puts "Attempting to retrieve from #{URLS['nyt']}"
  
## warning: Lazy, hazardous assignment here
## Hopefully you know the difference between a single and double equals sign
  if (json = RestClient.get(URLS['nyt'])) && json.code==200
    File.open(nyt_congress_json_name, 'w'){|f| f.write(json.body)}
  end
  
end  


senate_json = Crack::JSON.parse(File.open(nyt_congress_json_name, 'r').read)

## Step C. Get the Face.com face meta-data for each Senator's image file
## More information can be found at:
 
# http://developers.face.com/
# http://ruby.bastardsbook.com/chapters/image-manipulation/

face_api_key, face_api_secret = KEYS['face'].split(',')

# iterate through each member in the Senate JSON file
senators = senate_json['results'][0]['members']
puts "Number of senators: #{senators.length}"

senators.each do |senator|
  
  # remember the zipfile path from step B?
  img_filename = File.join(zip_basename, senator['id']+'.jpg')
  img_meta_filename = File.join(zip_basename, senator['id']+'.json')
  
  unless File.exists?(img_meta_filename)
    if !File.exists?(img_filename)
      raise "The image file #{img_filename} is not where it should be"
    else
      puts "Attempting #{senator['id']} - #{senator['first_name']} #{senator['last_name']}"
      
      # RestClient happily supports file uploads

      face_json = RestClient.post( URLS['face'],
               {:file=>File.open(img_filename, 'rb'), 
                 :api_key=>face_api_key,
                 :api_secret=>face_api_secret,
                 :format=>'json',
                 :attributes=>'all'
                }
              ) # RestClient.post takes in two arguments here  
      
      if face_json.code==200
        File.open(img_meta_filename, 'w'){|f| f.write(face_json)}
      end       
      
      # take a short breather     
      sleep rand
      
    end
  end
  
end


# Congressmiles: A tutorial on Face.com, NYT Congress, and Sunlight Foundation API
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
# http://ruby.bastardsbook.com
#


