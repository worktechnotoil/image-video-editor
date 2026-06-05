require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "ImageVideoEditor"
  s.version      = package["version"]
  s.summary      = "A high-performance React Native image and video editor."
  s.description  = package["description"]
  s.homepage     = "https://github.com/worktechnotoil/image-video-editor"
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/worktechnotoil/image-video-editor.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.resources    = "ios/frames/*.png"

  install_modules_dependencies(s)
end
