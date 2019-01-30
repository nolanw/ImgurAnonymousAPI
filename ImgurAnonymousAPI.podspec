Pod::Spec.new do |s|
  s.name          = "ImgurAnonymousAPI"
  s.version       = "1.0"
  s.summary       = "Upload images 'anonymously' to Imgur."
  s.homepage      = "https://github.com/nolanw/ImgurAnonymousAPI"
  s.license       = "Public domain"
  s.authors       = { "Nolan Waite" => "nolan@nolanw.ca" }
  s.platform      = :ios, "9.0"
  s.source        = { :git => "https://github.com/nolanw/ImgurAnonymousAPI", :tag => "#{s.version}" }
  s.source_files  = "Sources/*.swift"
  s.swift_version = "4.2"
  s.frameworks    = "ImageIO", "Photos", "UIKit"
end
