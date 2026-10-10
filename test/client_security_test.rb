# frozen_string_literal: true
require_relative "test_helper"

# Security checks against the published Gem. Internal stubs are test-only.
class ClientSecurityTest < Minitest::Test
  ORIGIN = "https://agent.example.com"
  CARD = "#{ORIGIN}/.well-known/agent-card.json"

  class TimeoutResolver
    attr_reader :calls

    def initialize
      @calls = []
    end

    def rpc(method:, params:, id:)
      @calls << { method: method, params: params, id: id }
      raise A2A::Rails::Client::PinnedHttpsTransport::DeadlineExceeded.new(:timeout)
    end
  end

  def env(extra = {})
    {
      "A2A_AGENT_CARD_URL" => CARD,
      "A2A_ALLOWED_ORIGINS" => "#{ORIGIN},https://rpc.example.com"
    }.merge(extra)
  end

  def test_wrong_scheme_and_unapproved_origin_rejected_without_network
    [
      "http://agent.example.com/.well-known/agent-card.json",
      "https://unapproved.example.com/card"
    ].each do |url|
      assert_raises(A2A::Rails::Client::ConfigurationError) do
        AgentClientDemo::ClientFactory.build(env: env("A2A_AGENT_CARD_URL" => url))
      end
    end
  end

  def test_both_rpc_and_card_credentials_require_exact_allowlisted_origin
    [
      { "A2A_RPC_TOKEN" => "test-secret" },
      { "A2A_RPC_CREDENTIAL_ORIGIN" => ORIGIN },
      { "A2A_CARD_TOKEN" => "test-secret" },
      { "A2A_CARD_CREDENTIAL_ORIGIN" => ORIGIN },
      { "A2A_RPC_TOKEN" => "test-secret", "A2A_RPC_CREDENTIAL_ORIGIN" => "https://unapproved.example.com" },
      { "A2A_CARD_TOKEN" => "test-secret", "A2A_CARD_CREDENTIAL_ORIGIN" => "http://agent.example.com" }
    ].each do |options|
      error = assert_raises(ArgumentError) { AgentClientDemo::ClientFactory.build(env: env(options)) }
      refute_includes error.full_message, "test-secret"
    end
  end

  def test_card_and_rpc_credentials_bound_to_distinct_origins
    client = AgentClientDemo::ClientFactory.build(env: env(
      "A2A_RPC_TOKEN" => "rpc-test-value",
      "A2A_RPC_CREDENTIAL_ORIGIN" => "https://rpc.example.com",
      "A2A_CARD_TOKEN" => "card-test-value",
      "A2A_CARD_CREDENTIAL_ORIGIN" => ORIGIN
    ))
    assert_instance_of A2A::Rails::Client, client
    resolver = client.instance_variable_get(:@resolver)
    assert_equal "https://rpc.example.com", resolver.instance_variable_get(:@credential_origin)
    assert_equal ORIGIN, resolver.instance_variable_get(:@card_credential_origin)
  end

  def test_invalid_configuration_does_not_log_credential
    marker = "NEVER_PRINT_TEST_CREDENTIAL"
    out, err = capture_io do
      ex = assert_raises(ArgumentError) do
        AgentClientDemo::ClientFactory.build(env: env(
          "A2A_RPC_TOKEN" => marker,
          "A2A_RPC_CREDENTIAL_ORIGIN" => "https://unapproved.example.com"
        ))
      end
      refute_includes ex.message, marker
    end
    refute_includes out, marker
    refute_includes err, marker
  end

  def test_rejects_mixed_private_dns_metadata_and_loopback
    [
      ["8.8.8.8", "127.0.0.1"],
      ["8.8.8.8", "169.254.169.254"],
      ["10.0.0.1"],
      ["::1", "8.8.8.8"]
    ].each do |addresses|
      policy = A2A::Rails::Client::OutboundPolicy.new(
        allowed_origins: [ORIGIN], resolver: ->(_host) { addresses }
      )
      failure = assert_raises(A2A::Rails::Client::OutboundPolicy::RejectedTarget) do
        policy.resolve!(CARD)
      end
      assert_equal :blocked_ip, failure.reason
    end
  end

  def test_ambiguous_timeout_does_not_retry_send_or_cancel
    client = AgentClientDemo::ClientFactory.build(env: env)
    resolver = TimeoutResolver.new
    client.instance_variable_set(:@resolver, resolver) # isolated unit-test seam

    send_failure = assert_raises(A2A::Rails::Client::TimeoutError) do
      client.send_message(message: {
        message_id: "original-message-id", role: "ROLE_USER", parts: [{ text: "test" }]
      })
    end
    assert_equal :send_message, send_failure.operation
    assert send_failure.may_have_executed
    assert_nil send_failure.cause
    assert_equal 1, resolver.calls.count { |call| call[:method] == "SendMessage" }
    assert_equal "original-message-id", resolver.calls.first.dig(:params, "message", "messageId")

    cancel_failure = assert_raises(A2A::Rails::Client::TimeoutError) do
      client.cancel_task(id: "remote-task")
    end
    assert_equal :cancel_task, cancel_failure.operation
    assert cancel_failure.may_have_executed
    assert_nil cancel_failure.cause
    assert_equal 1, resolver.calls.count { |call| call[:method] == "CancelTask" }
    assert_equal 2, resolver.calls.size
  end
end
