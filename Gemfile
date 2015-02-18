source "https://rubygems.org"

gemspec

group :development do
  gem 'byebug'
end

group :test do
  %w[ rspec rspec-core rspec-expectations rspec-mocks rspec-support ].each do |lib|
    gem lib, github: "rspec/#{lib}"
  end
  gem 'rspec-collection_matchers'
end

