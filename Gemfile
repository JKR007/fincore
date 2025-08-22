# frozen_string_literal: true

source "https://rubygems.org"

# Core Rails
gem "rails", ">= 8.0.2.1"
gem "pg", "~> 1.6"
gem "puma", ">= 5.0"

# Authentication
gem "jwt"

# System
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Security
gem "bundler-audit"

# API-specific
gem "rack-cors"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", ">= 7.1.0", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", "~> 3.2", require: false
  gem "rubocop-performance", "~> 1.23", require: false
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.5"
end

group :test do
  gem "simplecov", "~> 0.22", require: false
  gem "shoulda-matchers", "~> 6.4"
  gem "database_cleaner-active_record", "~> 2.2"
end

# Volunurability updates
gem "nokogiri", ">= 1.18.9"
gem "thor", ">= 1.4.0"
