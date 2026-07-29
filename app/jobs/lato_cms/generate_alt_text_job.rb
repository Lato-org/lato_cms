module LatoCms
  # Generates alt text for an image Media in the background via an
  # OpenAI-compatible LLM, so the upload request is not blocked on the API
  # call. Runs once per Media (not per field usage), since the same image
  # can be referenced by many fields. Failures are swallowed by the model
  # (logged as warnings): missing alt text must never break the upload.
  class GenerateAltTextJob < ApplicationJob
    queue_as :default

    def perform(media_id)
      LatoCms::Media.find_by(id: media_id)&.generate_alt_text!
    end
  end
end
