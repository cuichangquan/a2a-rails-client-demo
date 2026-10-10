# frozen_string_literal: true

module AgentClientDemo
  class ClientFactory
    def self.build(env: ENV)
      card_url = value(env, "A2A_AGENT_CARD_URL")
      origins = value(env, "A2A_ALLOWED_ORIGINS").to_s.split(",").map(&:strip).reject(&:empty?)

      if card_url.nil? || origins.empty?
        raise ArgumentError, "Configure A2A_AGENT_CARD_URL and A2A_ALLOWED_ORIGINS"
      end

      rpc_token = value(env, "A2A_RPC_TOKEN")
      card_token = value(env, "A2A_CARD_TOKEN")
      A2A::Rails::Client.new(
        agent_card_url: card_url,
        allowed_origins: origins,
        authorization: rpc_token && -> { "Bearer #{env.fetch('A2A_RPC_TOKEN')}" },
        credential_origin: rpc_token && value(env, "A2A_RPC_CREDENTIAL_ORIGIN"),
        card_authorization: card_token && -> { "Bearer #{env.fetch('A2A_CARD_TOKEN')}" },
        card_credential_origin: card_token && value(env, "A2A_CARD_CREDENTIAL_ORIGIN"),
        open_timeout: 3, read_timeout: 10, total_timeout: 15
      )
    end

    def self.value(env, key)
      raw = env[key]
      raw if raw.is_a?(String) && !raw.strip.empty?
    end
    private_class_method :value
  end
end
