# frozen_string_literal: true
# Explicitly disable the inbound Engine; this app is only an A2A Client.
A2A::Rails.configure do |config|
  config.server_enabled = false
end
