require "test_helper"

module LatoCms
  class ConfigTest < ActiveSupport::TestCase
    test "llm_configured? is false unless url, model, and api key are all set" do
      config = Config.new
      refute config.llm_configured?

      config.llm_api_url = "https://api.example.com/v1"
      refute config.llm_configured?

      config.llm_model = "gpt-4o-mini"
      refute config.llm_configured?

      config.llm_api_key = "sk-test"
      assert config.llm_configured?
    end
  end
end
