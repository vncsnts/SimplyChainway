Pod::Spec.new do |spec|
  spec.name         = "SimplyChainway"
  spec.version      = "0.2.2"
  spec.summary      = "Chainway R6 Pro SDK"
  spec.description  = "A wrapper for chainway SDK by Vince Santos"

  spec.homepage     = "https://github.com/VinceSantos/SimplyChainway"
  spec.license      = "MIT"
  spec.author             = { "Vince Santos" => "vince.santos@simplyrfid.com" }
  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/VinceSantos/SimplyChainway.git", :tag => spec.version.to_s }
  spec.source_files  = "SimplyChainway"
  spec.swift_versions = "5.0"
end
