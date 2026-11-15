# frozen_string_literal: true
require "securerandom"

module AgentClientDemo
  # A small business example using only the public Client interface. Protocol
  # keys are symbols; arbitrary keys inside Data remain JSON strings.
  class ReportProbe
    CONDITIONS = { "year" => 2026, "month" => 10, "department_id" => 123 }.freeze
    REPORT_FIELDS = %w[year month department_id sales_count total_amount currency].freeze
    class InvalidResult < StandardError; end

    def initialize(client:)
      @client = client
    end

    def run(conditions: CONDITIONS)
      result = @client.send_message(message: {
        message_id: SecureRandom.uuid,
        role: "ROLE_USER",
        parts: [{ data: conditions, media_type: "application/json" }]
      })
      raise InvalidResult, "Report requires the report Skill's Task response" unless result.kind == :task

      task = result.task
      fetched = @client.get_task(id: task.fetch(:id), history_length: 0)
      summary = {
        kind: "task", task_id: task.fetch(:id),
        state: task.dig(:status, :state), fetched_state: fetched.dig(:status, :state)
      }
      raise InvalidResult, "Report Task state differs on retrieval" unless summary[:state] == summary[:fetched_state]
      return summary unless summary[:state] == "TASK_STATE_COMPLETED"

      report = read_report(task)
      raise InvalidResult, "Report differs on retrieval" unless report == read_report(fetched)
      raise InvalidResult, "Report conditions differ from the request" unless report.slice(*CONDITIONS.keys) == conditions
      summary.merge(report: report)
    end

    private

    def read_report(task)
      data = task.dig(:artifacts, 0, :parts, 0, :data)
      unless data.is_a?(Hash) && data.keys.sort == REPORT_FIELDS.sort &&
          REPORT_FIELDS.reject { |key| key == "currency" }.all? { |key| data[key].is_a?(Integer) } &&
          data["currency"] == "JPY" && data["sales_count"] >= 0 && data["total_amount"] >= 0
        raise InvalidResult, "Expected the report Skill's fixed report fields"
      end
      # Only known synthetic report fields are printed, never arbitrary remote
      # Parts, status messages, credentials, or complete protocol envelopes.
      data.slice(*REPORT_FIELDS)
    end
  end
end
