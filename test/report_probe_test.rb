# frozen_string_literal: true
require "minitest/autorun"
require_relative "../app/services/agent_client_demo/report_probe"

class ReportProbeTest < Minitest::Test
  FakeResult = Struct.new(:kind, :task)
  EXPECTED = {
    "year" => 2026, "month" => 10, "department_id" => 123,
    "sales_count" => 3, "total_amount" => 35_000, "currency" => "JPY"
  }.freeze

  class FakeClient
    attr_reader :messages, :gets

    def initialize(reported_month: 10)
      @messages = []
      @gets = []
      @reported_month = reported_month
    end

    def send_message(message:)
      @messages << message
      valid = message.fetch(:parts).first.fetch(:data).fetch("month") != 13
      @task = { id: "report-1", status: { state: valid ? "TASK_STATE_COMPLETED" : "TASK_STATE_REJECTED" } }
      @task[:artifacts] = [{ parts: [{ data: EXPECTED.merge("month" => @reported_month) }] }] if valid
      FakeResult.new(:task, @task)
    end

    def get_task(id:, history_length:)
      @gets << [id, history_length]
      Marshal.load(Marshal.dump(@task))
    end
  end

  def test_conditions_are_a_data_part_and_report_is_read_after_get_task
    client = FakeClient.new
    result = AgentClientDemo::ReportProbe.new(client: client).run
    message = client.messages.fetch(0)
    assert_equal "ROLE_USER", message.fetch(:role)
    refute_empty message.fetch(:message_id)
    assert_equal [{ data: { "year" => 2026, "month" => 10, "department_id" => 123 }, media_type: "application/json" }], message.fetch(:parts)
    assert_equal EXPECTED, result.fetch(:report)
    assert_equal "TASK_STATE_COMPLETED", result.fetch(:state)
    assert_equal result.fetch(:state), result.fetch(:fetched_state)
    assert_equal [["report-1", 0]], client.gets
    assert_equal 1, client.messages.length
  end

  def test_invalid_month_is_a_business_rejection_without_report_or_retry
    client = FakeClient.new
    result = AgentClientDemo::ReportProbe.new(client: client).run(
      conditions: AgentClientDemo::ReportProbe::CONDITIONS.merge("month" => 13))
    assert_equal "TASK_STATE_REJECTED", result.fetch(:state)
    assert_equal result.fetch(:state), result.fetch(:fetched_state)
    refute result.key?(:report)
    assert_equal 1, client.messages.length
    assert_equal [["report-1", 0]], client.gets
  end

  def test_a_report_for_another_month_is_not_the_requested_result
    client = FakeClient.new(reported_month: 9)
    assert_raises(AgentClientDemo::ReportProbe::InvalidResult) do
      AgentClientDemo::ReportProbe.new(client: client).run
    end
    assert_equal 1, client.messages.length
    assert_equal [["report-1", 0]], client.gets
  end
end
