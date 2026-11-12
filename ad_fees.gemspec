require_relative "lib/ad_fees/version"

# The gemspec's name is the plugin's key and its table prefix.
Gem::Specification.new do |spec|
  spec.name = "ad_fees"
  spec.version = AdFees::VERSION
  spec.summary = "A Runwell plugin: a monthly management fee on ad spend, worked out from LuminAds and drafted in QuickBooks"
  spec.authors = [ "Martin Business Consultants" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-ad-fees"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
