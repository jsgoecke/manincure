#! /usr/bin/ruby
# manincure.rb version 0.6

# These arrays contain all the other presets and hashes that are going to be used.
# Yeah, they're global variables. In an object-oriented scripting language.
# Real smooth, huh?
$presetMasterList = []
$hashMasterList = []

# This class is pretty much everything. It contains multitudes.
class PresetClass
  
  # A width of 40 gives nice, compact output.
  @@columnWidth=40
  
  # Running initialization runs everything.
  # Calling it will also call the parser
  # and display output.
  def initialize
    
    # Grab input from the user's presets .plist
    rawPresets = readPresetPlist
    
    # Store all the presets in here
    presetStew = []

    # Each item in the array is one line from the .plist
    presetStew = rawPresets.split("\n")
    
    # Now get rid of white space
    presetStew = cleanStew(presetStew)
    
    # This stores the offsets between presets.
    presetBreaks = findPresetBreaks(presetStew)

    # Now it's time to use that info to store each
    # preset individually, in the master list.
    i = 0
    while i <= presetBreaks.size    
      if i == 0 #first preset
        # Grab the stew, up to the 1st offset.
        $presetMasterList[i] = presetStew.slice(0..presetBreaks[i].to_i)
      elsif i < presetBreaks.size #middle presets
        # Grab the stew from the last offset to the current..
        $presetMasterList[i] = presetStew.slice(presetBreaks[i-1].to_i..presetBreaks[i].to_i)
      else #final preset
        # Grab the stew, starting at the last offset, all the way to the end.
        $presetMasterList[i] = presetStew.slice(presetBreaks[i-1].to_i..presetStew.length)
      end
      i += 1
    end
    
    # Parse the presets into hashes
    buildPresetHash
    
    # Print to screen.
    displayCommandStrings
    
  end

  def readPresetPlist # Grab the .plist and store it in presets
    
    # Grab the user's home path
    homeLocation = `echo $HOME`.chomp
    
    # Use that to build a path to the presets .plist
    inputFile = homeLocation+'/Library/Application\ Support/HandBrake/UserPresets.plist'
    
    # Builds a command that inputs the .plist, but not before stripping all the XML gobbledygook.
    parseCommand = 'cat '+inputFile+' | sed -e \'s/<[a-z]*>//\' -e \'s/<\/[a-z]*>//\'  -e \'/<[?!]/d\' '
    
    puts "\n\n"
    
    # Run the command, return the raw presets
    rawPresets = `#{parseCommand}`
  end

  def cleanStew(presetStew) #remove tabbed white space
    presetStew.each do |oneline|
      oneline.strip!
    end
  end

  def findPresetBreaks(presetStew) #figure out where each preset starts and ends
    i = 0
    j = 0
    presetBreaks =[]
    presetStew.each do |presetLine|
      if presetLine =~ /AudioBitRate/ # This is the first line of a new preset.
        presetBreaks[j] = i-1         # So mark down how long the last one was.
        j += 1
      end
    i += 1
    end
    return presetBreaks
  end

  def buildPresetHash #fill up $hashMasterList with hashes of all key/value pairs
    j = 0
    
    # Iterate through all presets, treating each in turn as singleServing
    $presetMasterList.each do |singleServing|

      # Each key and value are on sequential lines.
      # Iterating through by twos, use that to build a hash.
      # Each key, on line i, paired with its value, on line i+1  
      tempHash = Hash.new
      i = 1
      while i < singleServing.length
        tempHash[singleServing[i]] = singleServing[i+1]
        i += 2
      end
      
      # Now store that hash in the master list.
      $hashMasterList[j]=tempHash
      
      j += 1  
    end   
  end

  def displayCommandStrings # prints everything to screen
    
    # Iterate through the hashes.    
    $hashMasterList.each do |hash|
    
      # Check to make there are valid contents
      if hash.key?("PresetName")
        
        # First throw up a header to make each preset distinct
        displayHeader(hash)
        
        # Show the preset's full CLI string equivalent
        generateCLIString(hash)
        
        # Show the preset as code for test/test.c, HandBrakeCLI
        generateAPIcalls(hash)
        
        # Show the preset as print statements, for CLI wrappers to parse.
        generateCLIPresetList(hash) 
        
      end
    end    
  end
  
  def displayHeader(hash) # A distinct banner to separate each preset
    
    # Print a line of asterisks
    puts "*" * @@columnWidth
    
    # Print the name, centered
    puts '* '+hash["PresetName"].to_s.center(@@columnWidth-4)+' *'
    
    # Print a line of dashes
    puts '~' * @@columnWidth
    
    # Print the description, centered and word-wrapped
    puts hash["PresetDescription"].to_s.center(@@columnWidth).gsub(/\n/," ").scan(/\S.{0,#{@@columnWidth-2}}\S(?=\s|$)|\S+/)
    
    # Print another line of dashes
    puts '~' * @@columnWidth
    
    # Print the formats the preset uses
    puts "#{hash["FileCodecs"]}".center(@@columnWidth)
    
    # Note if the preset isn't built-in
    if hash["Type"].to_i == 1
      puts "Custom Preset".center(@@columnWidth)
    end

    # Note if the preset is marked as default.
    if hash["Default"].to_i == 1
      puts "This is your default preset.".center(@@columnWidth)
    end
    
    # End with a line of tildes.  
    puts "~" * @@columnWidth
    
  end
  
  def generateCLIString(hash) # Makes a full CLI equivalent of a preset
    commandString = ""
    commandString << './HandBrakeCLI -i DVD -o ~/Movies/movie.'
    
    #Filename suffix
    case hash["FileFormat"]
    when /MP4/
      commandString << "mp4 "
    when /AVI/
      commandString << "avi "
    when /OGM/
      commandString << "ogm "
    when /MKV/
      commandString << "mkv "
    end
    
    #Video encoder
    if hash["VideoEncoder"] != "FFmpeg"
      commandString << " -e "
      if hash["VideoEncoder"] == "x264 (h.264 Main)"
        commandString << "x264"
      elsif hash["VideoEncoder"] == "x264 (h.264 iPod)"
        commandString << "x264b30"
      else
        commandString << hash["VideoEncoder"].to_s.downcase
      end
    end

    #VideoRateControl
    case hash["VideoQualityType"].to_i
    when 0
      commandString << " -S " << hash["VideoTargetSize"]
    when 1
      commandString << " -b " << hash["VideoAvgBitrate"]
    when 2
      commandString << " -q " << hash["VideoQualitySlider"]
    end

    #FPS
    if hash["VideoFramerate"] != "Same as source"
      if hash["VideoFramerate"] == "23.976 (NTSC Film)"
        commandString << " -r " << "23.976"
      elsif hash["VideoFramerate"] == "29.97 (NTSC Video)"
        commandString << " -r " << "29.97"
      else
        commandString << " -r " << hash["VideoFramerate"]
      end
    end
    
    #Audio bitrate
    commandString << " -B " << hash["AudioBitRate"]
    #Audio samplerate
    commandString << " -R " << hash["AudioSampleRate"]
    #Audio encoder
    commandString << " -E "
    case hash["FileCodecs"]
    when /AAC/
      commandString << "faac"
    when /AC-3/
      commandString << "ac3"
    when /Vorbis/
      commandString << "vorbis"
    when /MP3/
      commandString << "lame"
    end
    
    #Container
    commandString << " -f "
    case hash["FileFormat"]
    when /MP4/
      commandString << "mp4"
    when /AVI/
      commandString << "avi"
    when /OGM/
      commandString << "ogm"
    when /MKV/
      commandString << "mkv"
    end
    
    #Cropping
    if !hash["PictureAutoCrop"].to_i
      commandString << " --crop "
      commandString << hash["PictureTopCrop"]
      commandString << ":"
      commandString << hash["PictureBottomCrop"]
      commandString << ":"
      commandString << hash["PictureLeftCrop"]
      commandString << ":"
      commandString << hash["PictureRightCrop"]
    end
    
    #Dimensions
    if hash["PictureWidth"].to_i != 0
      commandString << " -w "
      commandString << hash["PictureWidth"]
    end
    if hash["PictureHeight"].to_i != 0
      commandString << " -l "
      commandString << hash["PictureHeight"]
    end
    
    #Subtitles
    if hash["Subtitles"] != "None"
      commandString << " -s "
      commandString << hash["Subtitles"]
    end
    
    #x264 Options

    if hash["x264Option"] != ""
      commandString << " -x "
      commandString << hash["x264Option"]
    end
    
    #Booleans
    if hash["ChapterMarkers"].to_i == 1 then commandString << " -m" end
    if hash["PictureDeinterlace"].to_i == 1 then commandString << " -d" end
    if hash["PicturePAR"].to_i == 1 then commandString << " -p" end
    if hash["VideoGrayScale"].to_i == 1 then commandString << " -g" end
    if hash["VideoTwoPass"].to_i == 1 then commandString << " -2" end
    if hash["VideoTurboTwoPass"].to_i == 1 then commandString << " -T" end
    
    # That's it, print to screen now
    puts commandString
    puts "*" * @@columnWidth
    puts  "\n"
  end

  def generateAPIcalls(hash) # Makes a C version of the preset ready for coding into the CLI
    
    commandString = "if (!strcmp(preset_name, \"" << hash["PresetName"] << "\"))\n{\n\t"
    
    #Filename suffix
    case hash["FileFormat"]
    when /MP4/
      commandString << "mux = " << "HB_MUX_MP4;\n\t"
    when /AVI/
      commandString << "mux = " << "HB_MUX_AVI;\n\t"
    when /OGM/
      commandString << "mux = " << "HB_MUX_OGM;\n\t"
    when /MKV/
      commandString << "mux = " << "HB_MUX_MKV;\n\t"
    end
    
    #Video encoder
    if hash["VideoEncoder"] != "FFmpeg"
      commandString << "vcodec = "
      if hash["VideoEncoder"] == "x264 (h.264 Main)"
        commandString << "HB_VCODEC_X264;\n\t"
      elsif hash["VideoEncoder"] == "x264 (h.264 iPod)"
        commandString << "HB_VCODEC_X264;\njob->h264_level = 30;\n\t"
      elsif hash["VideoEncoder"].to_s.downcase == "xvid"
        commandString << "HB_VCODEC_XVID;\n\t"        
      end
    end

    #VideoRateControl
    case hash["VideoQualityType"].to_i
    when 0
      commandString << "size = " << hash["VideoTargetSize"] << ";\n\t"
    when 1
      commandString << "job->vbitrate = " << hash["VideoAvgBitrate"] << ";\n\t"
    when 2
      commandString << "job->vquality = " << hash["VideoQualitySlider"] << ";\n\t"
    end

    #FPS
    if hash["VideoFramerate"] != "Same as source"
      if hash["VideoFramerate"] == "23.976 (NTSC Film)"
        commandString << "job->vrate_base = " << "1126125;\n\t"
      elsif hash["VideoFramerate"] == "29.97 (NTSC Video)"
        commandString << "job->vrate_base = " << "900900;\n\t"
      # Gotta add the rest of the framerates for completion's sake.
      end
    end
    
    #Audio bitrate
    commandString << "job->abitrate = " << hash["AudioBitRate"] << ";\n\t"
    
    #Audio samplerate
    commandString << "job->arate = "
    case hash["AudioSampleRate"]
    when /48/
      commandString << "48000"
    when /44.1/
      commandString << "44100"
    when /32/
      commandString << "32000"
    when /24/
      commandString << "24000"
    when /22.05/
      commandString << "22050"
    end
    commandString << ";\n\t"
    
    #Audio encoder
    commandString << "acodec = "
    case hash["FileCodecs"]
    when /AAC/
      commandString << "HB_ACODEC_FAAC;\n\t"
    when /AC-3/
      commandString << "HB_ACODEC_AC3;\n\t"
    when /Vorbis/
      commandString << "HB_ACODEC_VORBIS;\n\t"
    when /MP3/
      commandString << "HB_ACODEC_LAME;\n\t"
    end
    
    #Cropping
    if !hash["PictureAutoCrop"].to_i
      commandString << "job->crop[0] = " << hash["PictureTopCrop"] << ";\n\t"
      commandString << "job->crop[1] = " << hash["PictureBottomCrop"] << ";\n\t"
      commandString << "job->crop[2] = " << hash["PictureLeftCrop"] << ";\n\t"
      commandString << "job->crop[4] - " << hash["PictureRightCrop"] << ";\n\t"
    end
    
    #Dimensions
    if hash["PictureWidth"].to_i != 0
      commandString << "job->width = "
      commandString << hash["PictureWidth"] << ";\n\t"
    end
    if hash["PictureHeight"].to_i != 0
      commandString << "job->height = "
      commandString << hash["PictureHeight"] << ";\n\t"
    end
    
    #Subtitles
    if hash["Subtitles"] != "None"
      commandString << "job->subtitle = "
      commandString << ( hash["Subtitles"].to_i - 1).to_s << ";\n\t"
    end
    
    #x264 Options
    if hash["x264Option"] != ""
      commandString << "x264opts = strdup(\""
      commandString << hash["x264Option"] << "\");\n\t"
    end
    
    #Booleans
    if hash["ChapterMarkers"].to_i == 1 then commandString << "job->chapter_markers = 1;\n\t" end
    if hash["PictureDeinterlace"].to_i == 1 then commandString << "job->deinterlace = 1;\n\t" end
    if hash["PicturePAR"].to_i == 1 then commandString << "pixelratio = 1;\n\t" end
    if hash["VideoGrayScale"].to_i == 1 then commandString << "job->grayscale = 1;\n\t" end
    if hash["VideoTwoPass"].to_i == 1 then commandString << "twoPass = 1;\n\t" end
    if hash["VideoTurboTwoPass"].to_i == 1 then commandString << "turbo_opts_enabled = 1;\n" end
    
    commandString << "}"
    
    # That's it, print to screen now
    puts commandString
    #puts "*" * @@columnWidth
    puts  "\n"
  end

  def generateCLIPresetList(hash) # Makes a list of the CLI options a preset uses, for wrappers to parse
    commandString = ""
    commandString << "printf(\"\\n+ " << hash["PresetName"] << ": "
        
    #Video encoder
    if hash["VideoEncoder"] != "FFmpeg"
      commandString << " -e "
      if hash["VideoEncoder"] == "x264 (h.264 Main)"
        commandString << "x264"
      elsif hash["VideoEncoder"] == "x264 (h.264 iPod)"
        commandString << "x264b30"
      else
        commandString << hash["VideoEncoder"].to_s.downcase
      end
    end

    #VideoRateControl
    case hash["VideoQualityType"].to_i
    when 0
      commandString << " -S " << hash["VideoTargetSize"]
    when 1
      commandString << " -b " << hash["VideoAvgBitrate"]
    when 2
      commandString << " -q " << hash["VideoQualitySlider"]
    end

    #FPS
    if hash["VideoFramerate"] != "Same as source"
      if hash["VideoFramerate"] == "23.976 (NTSC Film)"
        commandString << " -r " << "23.976"
      elsif hash["VideoFramerate"] == "29.97 (NTSC Video)"
        commandString << " -r " << "29.97"
      else
        commandString << " -r " << hash["VideoFramerate"]
      end
    end
    
    #Audio bitrate
    commandString << " -B " << hash["AudioBitRate"]
    #Audio samplerate
    commandString << " -R " << hash["AudioSampleRate"]
    #Audio encoder
    commandString << " -E "
    case hash["FileCodecs"]
    when /AAC/
      commandString << "faac"
    when /AC-3/
      commandString << "ac3"
    when /Vorbis/
      commandString << "vorbis"
    when /MP3/
      commandString << "lame"
    end
    
    #Container
    commandString << " -f "
    case hash["FileFormat"]
    when /MP4/
      commandString << "mp4"
    when /AVI/
      commandString << "avi"
    when /OGM/
      commandString << "ogm"
    when /MKV/
      commandString << "mkv"
    end
    
    #Cropping
    if !hash["PictureAutoCrop"].to_i
      commandString << " --crop "
      commandString << hash["PictureTopCrop"]
      commandString << ":"
      commandString << hash["PictureBottomCrop"]
      commandString << ":"
      commandString << hash["PictureLeftCrop"]
      commandString << ":"
      commandString << hash["PictureRightCrop"]
    end
    
    #Dimensions
    if hash["PictureWidth"].to_i != 0
      commandString << " -w "
      commandString << hash["PictureWidth"]
    end
    if hash["PictureHeight"].to_i != 0
      commandString << " -l "
      commandString << hash["PictureHeight"]
    end
    
    #Subtitles
    if hash["Subtitles"] != "None"
      commandString << " -s "
      commandString << hash["Subtitles"]
    end
        
    #Booleans
    if hash["ChapterMarkers"].to_i == 1 then commandString << " -m" end
    if hash["PictureDeinterlace"].to_i == 1 then commandString << " -d" end
    if hash["PicturePAR"].to_i == 1 then commandString << " -p" end
    if hash["VideoGrayScale"].to_i == 1 then commandString << " -g" end
    if hash["VideoTwoPass"].to_i == 1 then commandString << " -2" end
    if hash["VideoTurboTwoPass"].to_i == 1 then commandString << " -T" end
    
      #x264 Options
      if hash["x264Option"] != ""
        commandString << " -x "
        commandString << hash["x264Option"]
      end
    
    commandString << "\\n\");"
    
    # That's it, print to screen now
    puts commandString
    puts  "\n"
  end

end

# This line is the ignition.
PresetClass.new