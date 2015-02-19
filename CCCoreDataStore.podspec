Pod::Spec.new do |s|

  s.name         = "CCCoreDataStore"
  s.version      = "1.1.0"
  s.summary      = "A simple and functional CoreData wrapper"
  s.homepage     = "https://github.com/catshive/CCCoreDataStore"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = "Cathy Shive"
  s.social_media_url   = "http://twitter.com/catshive"
  s.platform     = :ios, "5.0"
  s.source       = { :git => "https://github.com/catshive/CCCoreDataStore.git", :tag => "1.1.0" }
  s.source_files  = "Classes", "Classes/CCCoreDataStore.{h,m}"
  s.framework  = "CoreData"
  s.requires_arc = true
  
end
