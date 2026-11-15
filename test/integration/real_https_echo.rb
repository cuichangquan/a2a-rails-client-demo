# frozen_string_literal: true

# TEST-ONLY: actual public Client API + Client-only Rails host -> independent
# Rails Server over the existing ephemeral TLS bridge and pinned loopback socket.
# Both applications load the published RubyGems 0.4.0 package.
# Do not copy the test-only policy/resolver into runtime application code.
ENV["RAILS_ENV"] = "test"
require_relative "../../config/environment"
require "bundler"
require "securerandom"

abort "Refuse non-test execution" unless Rails.env.test?
abort "Refuse non-CI test network override" unless ENV["STEP30_TEST_ONLY_TLS"] == "1"

module Step30HttpsInterop
  ORIGIN = "https://echo-agent.test:3443"
  CARD = "#{ORIGIN}/.well-known/agent-card.json"

  def self.check!(condition, label)
    raise "FAILED: #{label}" unless condition
    puts "PASS: #{label}"
  end

  # This override is deliberately test-scoped and never in app/, Gem or
  # configuration. Socket still pins its IP, verifies SNI/host and test CA.
  class TestOnlyLoopbackPolicy < A2A::Rails::Client::OutboundPolicy
    attr_reader :paths, :origins

    def initialize(allowed_origins:)
      super
      @paths = []
      @origins = []
    end

    def resolve!(url)
      uri = validate_url!(url) # Original exact HTTPS allowlist and URL checks.
      origin = "#{uri.scheme}://#{uri.host}:#{uri.port}"
      @paths << uri.path
      @origins << origin
      A2A::Rails::Client::OutboundPolicy::Target.new(
        url: uri.to_s.freeze,
        origin: origin.freeze,
        host: uri.host.freeze,
        port: uri.port,
        addresses: ["127.0.0.1"].freeze
      ).freeze
    end
  end

  def self.client_with_test_transport(origin:, ca_file:)
    client = A2A::Rails::Client.new(
      agent_card_url: "#{origin}/.well-known/agent-card.json",
      allowed_origins: [origin],
      open_timeout: 2, read_timeout: 5, total_timeout: 8
    )
    policy = TestOnlyLoopbackPolicy.new(allowed_origins: [origin])
    transport = A2A::Rails::Client::PinnedHttpsTransport.new(
      policy: policy, ca_file: ca_file,
      open_timeout: 2, read_timeout: 5, total_timeout: 8
    )
    resolver = A2A::Rails::Client::AgentCardResolver.new(
      agent_card_url: "#{origin}/.well-known/agent-card.json",
      policy: policy, transport: transport
    )
    # Deliberate white-box TEST-ONLY seam, no public production configuration.
    client.instance_variable_set(:@resolver, resolver)
    [client, policy]
  end

  def self.run!
    spec = Gem.loaded_specs.fetch("a2a-rails")
    source = Bundler.load.specs.find { |s| s.name == "a2a-rails" }&.source
    check!(spec.version.to_s == "0.4.0" && source.is_a?(Bundler::Source::Rubygems),
      "real Rails Client uses published RubyGems 0.4.0")

    ca = ENV.fetch("STEP30_TLS_CA")
    check!(File.file?(ca), "ephemeral test CA exists")

    # Regular shipped SSRF policy must ALWAYS reject a loopback DNS result.
    production = A2A::Rails::Client::OutboundPolicy.new(
      allowed_origins: [ORIGIN], resolver: ->(_host) { ["127.0.0.1"] }
    )
    begin
      production.resolve!(CARD)
      raise "Production SSRF policy unexpectedly allowed loopback"
    rescue A2A::Rails::Client::OutboundPolicy::RejectedTarget => error
      check!(error.reason == :blocked_ip, "production SSRF policy blocks loopback")
    end

    client, policy = client_with_test_transport(origin: ORIGIN, ca_file: ca)
    check!(client.is_a?(A2A::Rails::Client), "normal public Client facade constructed")

    # TLS peer/host verification MUST remain enabled. A different hostname
    # with the SAME test CA and pinned socket must fail TLS.
    mismatched, = client_with_test_transport(
      origin: "https://wrong-agent.test:3443", ca_file: ca
    )
    begin
      mismatched.agent_card
      raise "Wrong TLS hostname was accepted"
    rescue A2A::Rails::Client::TransportError => error
      check!(error.reason == :connection_failed, "TLS hostname mismatch rejected")
    end

    card = client.agent_card
    check!(card.fetch(:name) == "Echo Agent", "independent Rails Agent Card discovered via TLS")
    interface = card.fetch(:supported_interfaces).find { |i|
      i[:protocol_binding] == "JSONRPC" && i[:protocol_version] == "1.0"
    }
    check!(interface && interface[:url] == "#{ORIGIN}/a2a",
      "real HTTPS JSON-RPC v1.0 interface selected from Agent Card")

    message = "Hello from Client-only Rails"
    result = client.send_message(message: {
      message_id: SecureRandom.uuid,
      role: "ROLE_USER",
      parts: [{ text: message }]
    })
    check!(result.kind == :task, "SendMessage produced remote Task")
    task = result.task
    check!(task.dig(:status, :state) == "TASK_STATE_COMPLETED",
      "remote Task completed")
    check!(task.dig(:artifacts, 0, :parts, 0, :text) == "Echo: #{message}",
      "server business Service returned expected Artifact")
    remote_id = task.fetch(:id)
    fetched = client.get_task(id: remote_id, history_length: 0)
    check!(fetched[:id] == remote_id &&
      fetched.dig(:status, :state) == "TASK_STATE_COMPLETED", "GetTask matched Task")
    page = client.list_tasks(context_id: task.fetch(:context_id),
      page_size: 10, history_length: 0, include_artifacts: false)
    check!(page.tasks.any? { |entry| entry.fetch(:id) == remote_id },
      "ListTasks filtered by remote context includes Task")
    check!(page.next_page_token.is_a?(String) && page.total_size >= 1,
      "ListTasks pagination metadata decoded")

    direct_text = "direct: hello from independent Client"
    direct = client.send_message(message: {
      message_id: SecureRandom.uuid,
      role: "ROLE_USER",
      parts: [{ text: direct_text }]
    })
    check!(direct.kind == :message && direct.task.nil?,
      "SendMessage returns direct Message without Task")
    check!(direct.message.dig(:parts, 0, :text) == "Echo: #{direct_text}",
      "direct Message contains actual remote Handler output")

    begin
      client.cancel_task(id: remote_id)
      raise "Unexpected cancellation of completed task"
    rescue A2A::Rails::Client::RemoteError => error
      check!(error.code == -32_002, "CancelTask terminal error code preserved")
    end

    # Also run the example app's *actual* service, not only protocol-level tests.
    summary = AgentClientDemo::Probe.new(client: client).run
    check!(summary[:agent] == "Echo Agent" &&
      summary[:samples].map { |r| r[:kind] } == %w[task message],
      "Client-only Rails Probe service executed against actual remote Rails Server")
    exercise_report!(client, card)
    check!((policy.paths & ["/.well-known/agent-card.json", "/a2a"]).size == 2,
      "both Agent Card and RPC used real pinned TLS transport")
    check!(policy.origins.uniq == [ORIGIN], "no other HTTPS origin used")
    puts "PUBLISHED 0.4.0 CLIENT <-> INDEPENDENT RAILS REPORT SERVER TLS: PASS"
  end

  def self.exercise_report!(client, card)
    report_skill = card.fetch(:skills).find { |skill| skill[:id] == "report" }
    check!(report_skill && report_skill[:input_modes] == ["application/json"],
      "report Skill explicitly advertises JSON input")
    conditions = { "year" => 2026, "month" => 10, "department_id" => 123 }
    expected = conditions.merge("sales_count" => 3, "total_amount" => 35_000, "currency" => "JPY")
    summary = AgentClientDemo::ReportProbe.new(client: client).run(conditions: conditions)
    check!(summary[:state] == "TASK_STATE_COMPLETED" && summary[:report] == expected,
      "real Rails report Service returns three sales totaling JPY 35000")
    fetched = client.get_task(id: summary.fetch(:task_id), history_length: 1)
    check!(fetched.dig(:history, 0, :parts, 0, :data) == conditions,
      "GetTask preserves the original report Data conditions")
    check!(fetched.dig(:history, 0, :parts, 0, :media_type) == "application/json",
      "GetTask preserves the report input mediaType")
    check!(fetched.dig(:artifacts, 0, :parts, 0, :data) == expected,
      "GetTask preserves the report Data Artifact")
    rejected = AgentClientDemo::ReportProbe.new(client: client).run(
      conditions: conditions.merge("month" => 13))
    check!(rejected[:state] == "TASK_STATE_REJECTED" && !rejected.key?(:report),
      "invalid business month is rejected without a report or automatic retry")
  end
end

Step30HttpsInterop.run!
