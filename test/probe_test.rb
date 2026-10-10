# frozen_string_literal: true
require_relative "test_helper"

class ProbeTest < Minitest::Test
  FakeResult = Struct.new(:kind, :task, :message)
  FakePage = Struct.new(:tasks)

  class FakeClient
    attr_reader :sent_texts, :got_ids, :listed_contexts

    def initialize
      @sent_texts = []
      @got_ids = []
      @listed_contexts = []
    end

    def agent_card
      { name: "Echo Agent" }
    end

    def send_message(message:)
      raise "invalid user message" unless message[:message_id].to_s.length > 1 && message[:role] == "ROLE_USER"
      text = message.fetch(:parts).first.fetch(:text)
      @sent_texts << text
      if text.start_with?("direct:")
        FakeResult.new(:message, nil,
          { message_id: "direct-1", parts: [{ text: "Echo" }] })
      else
        FakeResult.new(:task,
          { id: "task-1", context_id: "ctx-1", status: { state: "TASK_STATE_COMPLETED" },
            artifacts: [{ parts: [{ text: "Echo" }] }] }, nil)
      end
    end

    def get_task(id:, history_length:)
      @got_ids << [id, history_length]
      { id: id, status: { state: "TASK_STATE_COMPLETED" } }
    end

    def list_tasks(context_id:, page_size:, include_artifacts:)
      @listed_contexts << [context_id, page_size, include_artifacts]
      FakePage.new([{ id: "task-1" }])
    end
  end

  def test_task_and_direct_message_are_different_response_forms
    fake = FakeClient.new
    summary = AgentClientDemo::Probe.new(client: fake).run
    assert_equal "Echo Agent", summary.fetch(:agent)
    task, direct = summary.fetch(:samples)
    assert_equal "task", task.fetch(:kind)
    assert_equal "TASK_STATE_COMPLETED", task.fetch(:fetched_state)
    assert_equal 1, task.fetch(:listed_tasks)
    assert_equal "message", direct.fetch(:kind)
    assert_equal 1, direct.fetch(:parts_count)
    assert_equal [["task-1", 0]], fake.got_ids
    assert_equal [["ctx-1", 10, false]], fake.listed_contexts
  end
end
