Pod::Spec.new do |s|
  s.name          = "ImgurAnonymousAPI"
  s.version       = `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Framework/Info.plist`.strip
  s.summary       = "Upload images 'anonymously' to Imgur."
  s.homepage      = "https://github.com/nolanw/ImgurAnonymousAPI"
  s.license       = "Public domain"
  s.authors       = { "Nolan Waite" => "nolan@nolanw.ca" }

  s.source        = { :git => "https://github.com/nolanw/ImgurAnonymousAPI.git", :tag => "v#{s.version}" }
  s.source_files  = "Sources/*.swift"
  s.swift_version = "4.2"

  s.ios.deployment_target = "9.0"
  s.ios.frameworks = "ImageIO", "Photos", "UIKit"

  s.osx.deployment_target = "10.11"
  s.osx.frameworks = "ImageIO", "Photos"

  s.tvos.deployment_target = "9.0"
  s.tvos.frameworks = "ImageIO"

  s.watchos.deployment_target = "2.0"
  s.watchos.frameworks = "ImageIO"
end
