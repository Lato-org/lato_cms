require 'net/http'

module LatoCms
  # Thin transport for the configured OpenAI-compatible chat completions
  # endpoint (see LatoCms::Config#llm_configured?). Callers own their own
  # prompt/response-shape concerns (e.g. LatoCms::Media for alt text,
  # LatoCms::PagesController for translating cloned fields); this class only
  # knows how to send `messages` and hand back the response's text content.
  class LlmClient
    class Error < StandardError; end

    def self.chat(messages:)
      uri = URI.join("#{LatoCms.config.llm_api_url.chomp('/')}/", 'chat/completions')

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{LatoCms.config.llm_api_key}"
      request.body = { model: LatoCms.config.llm_model, messages: messages }.to_json

      response = http.request(request)
      raise Error, "LLM request failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig('choices', 0, 'message', 'content')
    end
  end
end
