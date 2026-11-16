# frozen_string_literal: true

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  # metagem pulling in puppet-lint, rspec-puppet, rubocop and the rest
  gem 'voxpupuli-test', '~> 14.0', require: false
  # builds the test matrix from metadata.json
  gem 'puppet_metadata', '~> 6.1', require: false
end

group :release do
  gem 'voxpupuli-release', '~> 5.4', require: false
end

gem 'rake', require: false

# openvox, not puppet: the two ship different strings implementations, and
# REFERENCE.md has to match what the voxbox container generates.
gem 'openvox', ENV.fetch('OPENVOX_GEM_VERSION', ['>= 8', '< 10']), require: false, groups: [:test]
