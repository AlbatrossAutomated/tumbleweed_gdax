source 'https://rubygems.org'

ruby '2.6.0'

gem 'pg'
gem 'rake'
gem 'awesome_print'
gem 'coinbase-exchange', '0.1.1'
gem 'sinatra'
gem 'dotenv-rails'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '5.2.3'
# Use Puma as the app server
gem 'puma', '~> 3.12'
gem 'clockwork', require: false
gem 'active_attr'

# needed in prod if git pushing Heroku
gem 'brakeman', require: false
gem 'bundler-audit', require: false
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

gem 'bootsnap', require: false

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'rails_best_practices', require: false
  gem 'reek', require: false
  gem 'byebug', platform: :mri
end

group :development do
  gem 'web-console'
  gem 'listen'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen'
end

group :test do
  gem 'json_spec'
  gem 'database_cleaner'
  # IMPORTANT! - Use caution when upgrading webmock
  # Currently any version past 3.1.1 makes live requests to the exchange API on spec runs. Yikes!!
  gem 'webmock', '3.1.1', require: false
  gem 'shoulda-matchers'
  gem 'simplecov'
  gem 'fantaskspec'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
