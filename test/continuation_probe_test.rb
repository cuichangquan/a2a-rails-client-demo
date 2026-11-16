# frozen_string_literal: true
require "minitest/autorun"
require_relative "../app/services/agent_client_demo/continuation_probe"

class ContinuationProbeTest < Minitest::Test
  FakeResult = Struct.new(:kind, :task)

  class FakeClient
    attr_reader :messages, :gets, :cancels

    def initialize(change_id: false, fail_answer: false)
      @messages, @gets, @cancels = [], [], []
      @criteria = {}
      @change_id, @fail_answer = change_id, fail_answer
    end

    def send_message(message:)
      @messages << message
      raise IOError, "simulated transport interruption" if @fail_answer && @messages.length > 1
      @criteria.merge!(message.fetch(:parts).first.fetch(:data))
      missing = %w[year month department_id] - @criteria.keys
      @task = { id: @change_id && @messages.length > 1 ? "wrong-task" : "task-1", context_id: "context-1",
        status: { state: missing.empty? ? "TASK_STATE_COMPLETED" : "TASK_STATE_INPUT_REQUIRED" } }
      if missing.empty?
        @task[:artifacts] = [{ parts: [{ data: @criteria.merge("sales_count" => 3,
          "total_amount" => 35_000, "currency" => "JPY") }] }]
      else
        @task[:status][:message] = { parts: [{ text: "Please provide: #{missing.join(', ')}." },
          { data: { "missing_fields" => missing } }] }
      end
      FakeResult.new(:task, @task)
    end

    def get_task(id:, history_length:)
      @gets << [id, history_length]
      Marshal.load(Marshal.dump(@task))
    end

    def cancel_task(id:)
      @cancels << id
      @task.merge(status: { state: "TASK_STATE_CANCELED" })
    end
  end

  def test_question_then_answer_uses_same_task_without_context_or_retry
    client = FakeClient.new
    result = AgentClientDemo::ContinuationProbe.new(client: client).run
    assert_equal "task-1", result[:task_id]
    assert_equal "TASK_STATE_COMPLETED", result[:state]
    assert_equal 35_000, result.dig(:report, "total_amount")
    assert_equal [{ text: "Please provide: department_id.", missing_fields: ["department_id"] }], result[:questions]
    assert_equal 2, client.messages.length
    answer = client.messages.last
    assert_equal "task-1", answer[:task_id]
    refute answer.key?(:context_id)
    assert_equal({ "department_id" => 123 }, answer.dig(:parts, 0, :data))
    assert_equal 2, client.messages.map { |message| message[:message_id] }.uniq.length
    assert_equal [["task-1", 0], ["task-1", 0]], client.gets
  end

  def test_two_questions_before_same_task_completion
    client = FakeClient.new
    result = AgentClientDemo::ContinuationProbe.new(client: client).run(reask: true)
    assert_equal [%w[month department_id], %w[department_id]], result[:questions].map { |q| q[:missing_fields] }
    assert_equal [nil, "task-1", "task-1"], client.messages.map { |m| m[:task_id] }
  end

  def test_cancel_does_not_send_an_answer
    client = FakeClient.new
    result = AgentClientDemo::ContinuationProbe.new(client: client).run(cancel: true)
    assert_equal "TASK_STATE_CANCELED", result[:state]
    assert_equal ["task-1"], client.cancels
    assert_equal 1, client.messages.length
    refute result.key?(:report)
  end

  def test_different_task_is_not_silently_accepted
    client = FakeClient.new(change_id: true)
    assert_raises(AgentClientDemo::ContinuationProbe::InvalidResult) do
      AgentClientDemo::ContinuationProbe.new(client: client).run
    end
    assert_equal 2, client.messages.length
  end

  def test_interrupted_answer_is_never_automatically_retried
    client = FakeClient.new(fail_answer: true)
    assert_raises(IOError) { AgentClientDemo::ContinuationProbe.new(client: client).run }
    assert_equal 2, client.messages.length
  end
end
