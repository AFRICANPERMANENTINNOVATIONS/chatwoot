require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    # Builds an isolated RubyLLM context using the account's own provider keys (BYOK).
    # Falls back to the system OpenAI key if no account key is configured for that provider.
    # The block is invoked with the configured context; pass it to context.chat / context.embed.
    # Thread-safe: mutations are scoped to the returned context object only.
    def with_account_keys(account)
      keys = account_provider_keys(account)
      context = RubyLLM.context do |config|
        config.openai_api_key = keys[:openai] if keys[:openai].present?
        config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
        config.anthropic_api_key = keys[:anthropic] if keys[:anthropic].present?
        config.gemini_api_key = keys[:gemini] if keys[:gemini].present?
      end

      yield context
    end

    # Temporarily mutates the GLOBAL RubyLLM config with the account's keys, runs the block,
    # then restores the previous global config. Required for libraries like ai-agents that
    # do not accept a per-call context (they read RubyLLM global config at chat time).
    #
    # WARNING: Not strictly thread-safe under multi-threaded Sidekiq. In practice the worst
    # case is a single failed/retried request when two tenants run Captain concurrently on
    # the same process, which is acceptable for self-hosted deployments. For hard isolation,
    # configure separate Sidekiq processes per tenant or use single-threaded workers for
    # Captain queues.
    def using_account_keys!(account)
      keys = account_provider_keys(account)
      previous = snapshot_global_keys
      apply_global_keys(keys)
      yield
    ensure
      apply_global_keys(previous) if previous
    end

    private

    def account_provider_keys(account)
      hooks = account.hooks.where(app_id: %w[openai anthropic gemini], status: 'enabled').index_by(&:app_id)
      {
        openai: hooks['openai']&.settings&.dig('api_key').presence || system_api_key,
        anthropic: hooks['anthropic']&.settings&.dig('api_key'),
        gemini: hooks['gemini']&.settings&.dig('api_key')
      }
    end

    def snapshot_global_keys
      cfg = RubyLLM.config
      {
        openai: cfg.openai_api_key,
        anthropic: cfg.anthropic_api_key,
        gemini: cfg.gemini_api_key
      }
    end

    def apply_global_keys(keys)
      RubyLLM.configure do |config|
        config.openai_api_key = keys[:openai]
        config.anthropic_api_key = keys[:anthropic]
        config.gemini_api_key = keys[:gemini]
      end
    end

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
        config.logger = Rails.logger
      end
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end
