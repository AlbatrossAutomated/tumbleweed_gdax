source 'https://rubygems.org'

ruby '2.4.2'

gem 'pg'
gem 'rake'
gem 'awesome_print'
gem 'coinbase-exchange', '0.1.1'
gem 'sinatra'
gem 'dotenv-rails'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.1.5'
# Use Puma as the app server
gem 'puma', '~> 3.0'
gem 'clockwork', require: false
gem 'active_attr'

# needed in prod git pushing Heroku
gem 'brakeman', :require => false
gem 'bundler-audit', :require => false
gem 'rubocop', require: false

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

group :development, :test do
  gem 'factory_girl'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'json_spec'
  gem 'database_cleaner'
  gem 'shoulda-matchers', '~> 2.8.0', require: false
  gem 'rails_best_practices', require: false
  gem 'reek', require: false
  gem 'byebug', platform: :mri
end

group :development do
  gem 'web-console'
  gem 'listen', '~> 3.0.5'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  gem 'simplecov'
  gem 'webmock'
  gem 'factory_girl_rails', '~> 4.0'
  gem 'fantaskspec'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
