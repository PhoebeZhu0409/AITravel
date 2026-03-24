ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "dotenv/load" # Load .env once at boot (before database.yml / initializers need ENV)
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
