require 'digest/md5'
require 'oily_png'
require 'digest/md5'
require 'fileutils'

def cut(in_file, out_file, from, to=nil)
  to = "-to #{to}" if to
  `ffmpeg -v warning -i #{in_file} -ss #{from} #{to} -c copy #{out_file}`
end

def concat(batch_file, out_file)
  `ffmpeg -v warning -f concat -i #{batch_file} -c copy #{out_file}`
end

def invert_ranges(ranges)
  ranges.flatten.each_cons(2).each_with_index.select{|e,i| i%2==1}.map(&:first) << [ranges.last.last]
end

def convert_seconds(s)
  Time.at(s).utc.strftime('%H:%M:%S')
end

def cutout(file, ranges, opts={})
  ranges = invert_ranges(ranges) if opts[:mode] == :cut
  md5 = Digest::MD5.file(file).hexdigest
  tmp_path = "/tmp/#{md5}/"
  batch_file = "#{tmp_path}list.txt"
  unless opts[:join_only] == true
    if File.exist?(tmp_path)
      puts "Path already exists: #{tmp_path}"
      #FileUtils.rm_rf(tmp_path)
      return
    end
    Dir.mkdir tmp_path
    ext = File.extname(file)
    File.open(batch_file, 'a') do |bf|
      ranges.each do |from, to|
        from_hms = convert_seconds(from)
        to_hms = convert_seconds(to) if to
        tmp_file = "#{tmp_path}#{from}-#{to||'end'}#{ext}"
        cut(file, tmp_file, from_hms, to_hms)
        bf.puts("file '#{tmp_file}'")
      end
    end
  end
  out_file = File.join(File.dirname(file), "no_recaps_#{File.basename(file)}")
  puts 'joining'
  concat(batch_file, out_file)
  FileUtils.rm_rf(tmp_path) unless opts[:keep_chunks] == true
end

def capture_frames(video_path, s=1, scale_height=50)
  md5 = Digest::MD5.file(video_path).hexdigest
  `mkdir -p tmp/#{md5}`
  `ffmpeg -i #{video_path} -vf "scale=-1:#{scale_height}, fps=1/#{s}" tmp/#{md5}/out%04d.png`
end

def duplicates(video_path)
  md5 = Digest::MD5.file(video_path).hexdigest
  images = Dir.glob("tmp/#{md5}/*.png")
  index = 1
  images[1..-1].reduce([]) do |memo, image|
    # check all previous images if image is a duplicate of them
    images[0..index-1].each{|i| memo << image if duplicate?(image, i)}
    index += 1
    memo
  end
end

def duplicate?(image_path1, image_path2)
  image1 = ChunkyPNG::Image.from_file(image_path1)
  image2 = ChunkyPNG::Image.from_file(image_path2)
  row1 = image1.row(image1.height/2)
  row2 = image2.row(image2.height/2)
  return false if row1.uniq == [255] || row2.uniq == [255] #keep black images
  differences = row1.reduce([]) do |memo, value|
    memo << value if value != row2.shift
    memo
  end
  differences.size < image1.width * 0.05
end

video_path = 'trailer.mp4'
#capture_frames(video_path, 5, 350)
p duplicates(video_path)
#cutout('trailer.mp4', [[0,6],[18,22],[52,61],[70,75],[95,106]], mode: :cut)




