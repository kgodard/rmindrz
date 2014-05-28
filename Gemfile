source 'https://rubygems.org'
ruby "1.9.3"

gem 'dm-core'
gem 'dm-migrations'
gem 'twilio-ruby'

group :production do
  gem "pg"
  gem "dm-postgres-adapter"
end

group :development, :test do
  gem "sqlite3"
  gem "dm-sqlite-adapter"
end
