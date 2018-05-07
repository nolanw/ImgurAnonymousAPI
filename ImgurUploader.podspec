Pod::Spec.new do |s|
  s.name          = "ImgurUploader"
  s.version       = "1.0"
  s.summary       = "Upload images 'anonymously' to Imgur."
  s.homepage      = "https://github.com/nolanw/ImgurUploader"
  s.license       = "Public domain"
  s.authors       = { "Nolan Waite" => "nolan@nolanw.ca" }
  s.platform      = :ios, "9.0"
  s.source        = { :git => "https://github.com/nolanw/ImgurUploader", :tag => "#{s.version}" }
  s.source_files  = "Sources/ImgurUploader/*.swift"
  s.swift_version = "4.0"
  s.frameworks    = "ImageIO", "Photos", "UIKit"
end
