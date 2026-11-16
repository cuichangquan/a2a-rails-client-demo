# frozen_string_literal: true
require "securerandom"

module AgentClientDemo
  # Bounded synthetic example, not a generic workflow, polling or retry API.
  # Each explicit answer is sent once. A transport error is left to the caller.
  class ContinuationProbe
    class InvalidResult < StandardError; end
    INPUT_REQUIRED = "TASK_STATE_INPUT_REQUIRED"
    FIELDS = %w[year month department_id].freeze

    def initialize(client:)
      @client = client
    end

    def run(reask: false, cancel: false)
      initial = reask ? { "year" => 2026 } : { "year" => 2026, "month" => 10 }
      task = send_data(initial)
      id = task.fetch(:id)
      context_id = task.fetch(:context_id)
      questions = [read_question(task)]
      fetched = @client.get_task(id: id, history_length: 0)
      check_identity!(fetched, id, context_id)
      raise InvalidResult, "Question changed on retrieval" unless read_question(fetched) == questions.last

      if cancel
        canceled = @client.cancel_task(id: id)
        check_identity!(canceled, id, context_id)
        raise InvalidResult, "Waiting Task was not canceled" unless canceled.dig(:status, :state) == "TASK_STATE_CANCELED"
        return { task_id: id, state: canceled.dig(:status, :state), questions: questions }
      end

      if reask
        task = send_data({ "month" => 10 }, task_id: id)
        check_identity!(task, id, context_id)
        questions << read_question(task)
      end

      # task_id alone deliberately exercises lookup of the stored context.
      task = send_data({ "department_id" => 123 }, task_id: id)
      check_identity!(task, id, context_id)
      fetched = @client.get_task(id: id, history_length: 0)
      check_identity!(fetched, id, context_id)
      expected = { "year" => 2026, "month" => 10, "department_id" => 123,
        "sales_count" => 3, "total_amount" => 35_000, "currency" => "JPY" }
      unless [task, fetched].all? { |entry| entry.dig(:status, :state) == "TASK_STATE_COMPLETED" &&
          entry.dig(:artifacts, 0, :parts, 0, :data) == expected }
        raise InvalidResult, "Continuation did not produce the expected synthetic report"
      end
      { task_id: id, state: task.dig(:status, :state), questions: questions, report: expected }
    end

    private

    def send_data(data, task_id: nil)
      message = { message_id: SecureRandom.uuid, role: "ROLE_USER",
        parts: [{ data: data, media_type: "application/json" }] }
      message[:task_id] = task_id if task_id
      result = @client.send_message(message: message)
      raise InvalidResult, "Continuation requires a Task" unless result.kind == :task
      result.task
    end

    def check_identity!(task, id, context_id)
      unless task[:id] == id && task[:context_id] == context_id
        raise InvalidResult, "Continuation changed Task or conversation identity"
      end
    end

    def read_question(task)
      raise InvalidResult, "Expected input-required state" unless task.dig(:status, :state) == INPUT_REQUIRED
      parts = task.dig(:status, :message, :parts)
      raise InvalidResult, "Expected a structured report question" unless parts.is_a?(Array)
      missing = parts.find { |part| part.key?(:data) }&.dig(:data, "missing_fields")
      unless missing.is_a?(Array) && !missing.empty? && missing.uniq == missing && (missing - FIELDS).empty?
        raise InvalidResult, "Unexpected report question fields"
      end
      expected_text = "Please provide: #{missing.join(', ')}."
      unless parts.find { |part| part.key?(:text) }&.fetch(:text) == expected_text
        raise InvalidResult, "Unexpected report question text"
      end
      # Return only the validated fixed demo question, not arbitrary remote data.
      { text: expected_text, missing_fields: missing }
    end
  end
end
