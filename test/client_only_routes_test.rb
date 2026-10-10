# frozen_string_literal: true
require_relative "test_helper"
require "rack/mock"

class ClientOnlyRoutesTest < Minitest::Test
  def test_no_inbound_agent_card_or_jsonrpc_routes
    app = Rack::MockRequest.new(Rails.application)
    # HTTP_HOST set to a loopback host to avoid the host authorization middleware.
    assert_equal 404, app.get("/.well-known/agent-card.json", "HTTP_HOST" => "localhost").status
    assert_equal 404, app.post("/a2a", "HTTP_HOST" => "localhost").status
  end
end
