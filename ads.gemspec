require_relative "lib/ads/version"

# The gemspec's name is the plugin's key and its table prefix.
Gem::Specification.new do |spec|
  spec.name = "ads"
  spec.version = Ads::VERSION
  spec.summary = "A Runwell plugin: what each ad service costs, kept current from LuminAds, with QuickBooks invoicing when switched on"
  spec.authors = [ "Martin Business Consultants" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-ads"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
