Pod::Spec.new do |spec|
  spec.name         = "SimplyChainway"
  spec.version      = "0.1.0"
  spec.summary      = "A Framework for Chainway R6 Pro UHF"
  spec.description  = "No Description"
  spec.homepage     = "https://github.com/VinceSantos/SimplyChainway"
  spec.license      = "MIT"
  spec.author             = { "Vince Santos" => "vince.santos@simplyrfid.com" }
  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/VinceSantos/SimplyChainway.git", :tag => spec.version.to_s }
  spec.source_files  = "SimplyChainway"
end
