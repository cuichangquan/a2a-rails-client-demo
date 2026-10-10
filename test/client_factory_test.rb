# frozen_string_literal: true
require_relative "test_helper"

class ClientFactoryTest < Minitest::Test
  def test_requires_explicit_target_and_allowlist
    assert_raises(ArgumentError) { AgentClientDemo::ClientFactory.build(env: {}) }
  end

  def test_no_private_or_http_target_accepted_by_published_client
    assert_raises(A2A::Rails::Client::ConfigurationError) do
      AgentClientDemo::ClientFactory.build(env: {
        "A2A_AGENT_CARD_URL" => "http://127.0.0.1:3000/.well-known/agent-card.json",
        "A2A_ALLOWED_ORIGINS" => "http://127.0.0.1:3000"
      })
    end
  end

  def test_explicit_https_target_builds_without_network_access
    client = AgentClientDemo::ClientFactory.build(env: {
      "A2A_AGENT_CARD_URL" => "https://agent.example.com/.well-known/agent-card.json",
      "A2A_ALLOWED_ORIGINS" => "https://agent.example.com"
    })
    assert_instance_of A2A::Rails::Client, client
  end
end
