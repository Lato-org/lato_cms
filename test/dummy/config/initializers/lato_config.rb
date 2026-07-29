Lato.configure do |config|
  config.application_title = 'Lato example app'
  config.application_version = LatoCms::VERSION

  config.session_root_path = :documentation_path
end

LatoCms.configure do |config|
  config.locales = [:en, :it, :de, :fr]
  config.llm_api_url = "https://api.openai.com/v1"
  config.llm_model = "gpt-4o-mini"
  config.llm_api_key = "..."
end
