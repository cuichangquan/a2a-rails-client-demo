# frozen_string_literal: true
require "securerandom"

module AgentClientDemo
  # Uses the real published public Client interface, not a private injected transport.
  # Returns only a small, safe summary. Remote Parts, raw errors and auth never enter logs.
  class Probe
    def initialize(client:)
      @client = client
    end

    def run
      card = @client.agent_card
      {
        agent: card.fetch(:name),
        protocol: "A2A v1.0 JSON-RPC",
        samples: [send_once("Hello from Rails Client"), send_once("direct: Hello from Rails Client")]
      }
    end

    private

    def send_once(text)
      result = @client.send_message(message: {
        message_id: SecureRandom.uuid,
        role: "ROLE_USER",
        parts: [{ text: text }]
      })
      case result.kind
      when :task
        task = result.task
        retrieved = @client.get_task(id: task.fetch(:id), history_length: 0)
        summary = {
          kind: "task",
          task_id: task.fetch(:id),
          state: task.dig(:status, :state),
          fetched_state: retrieved.dig(:status, :state),
          artifacts_count: Array(task[:artifacts]).length
        }
        if task[:context_id]
          page = @client.list_tasks(context_id: task.fetch(:context_id),
                                    page_size: 10, include_artifacts: false)
          summary[:listed_tasks] = page.tasks.length
        end
        summary
      when :message
        { kind: "message", message_id: result.message.fetch(:message_id),
          parts_count: result.message.fetch(:parts).length }
      else
        raise "Unsupported SendResult kind"
      end
    end
  end
end
