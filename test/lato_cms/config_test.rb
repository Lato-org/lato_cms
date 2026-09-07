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

    test "llm_media_attributes is empty until configured, then follows the per-attribute switches" do
      config = Config.new
      assert_empty config.llm_media_attributes

      config.llm_api_url = "https://api.example.com/v1"
      config.llm_model = "gpt-4o-mini"
      config.llm_api_key = "sk-test"
      assert_equal %i[alt_text title], config.llm_media_attributes
      assert config.llm_generates?("title")

      config.llm_generate_title = false
      assert_equal %i[alt_text], config.llm_media_attributes
      refute config.llm_generates?(:title)
    end

    test "llm_prompt falls back to the default prompt unless a custom one is set" do
      config = Config.new
      assert_equal Config::DEFAULT_LLM_PROMPTS[:alt_text], config.llm_prompt(:alt_text)
      assert_includes config.llm_prompt(:title), "{languages}"

      config.llm_alt_text_prompt = "Describe for {urls}"
      assert_equal "Describe for {urls}", config.llm_prompt("alt_text")
      assert_equal Config::DEFAULT_LLM_PROMPTS[:title], config.llm_prompt(:title)
    end
  end
end
