require 'digest/md5'
require 'oily_png'

def md5(video_path)
  @md5 ||= Digest::MD5.file(video_path).hexdigest
end

def capture_frames(video_path, s=1, scale_height=50)
  `mkdir -p tmp/#{md5(video_path)}`
  `ffmpeg -i #{video_path} -vf "scale=-1:#{scale_height}, fps=1/#{s}" tmp/#{md5(video_path)}/out%04d.png`
end

def duplicates(video_path)
  images = Dir.glob("tmp/#{md5(video_path)}/*.png")
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
  return false if row1.uniq == [255] || row2.uniq == [255]
  differences = row1.reduce([]) do |memo, value|
    memo << value if value != row2.shift
    memo
  end
  differences.size < image1.width * 0.05
end

video_path = 'trailer.mp4'
#capture_frames(video_path, 5, 350)
p duplicates(video_path)




