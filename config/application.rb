# frozen_string_literal: true
require_relative "boot"
require "logger"
require "securerandom"
require "action_controller/railtie"
require "a2a-rails"

# This is a Client-only local demo, not a public HTTP service.
unless ::Rails.env.development? || ::Rails.env.test?
  abort "Client demo is local-only: RAILS_ENV must be development or test"
end

module A2ARailsClientDemo
  class Application < ::Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = SecureRandom.hex(64)
    config.logger = Logger.new($stdout)
    config.filter_parameters += %i[authorization token secret password credential]
  end
end
