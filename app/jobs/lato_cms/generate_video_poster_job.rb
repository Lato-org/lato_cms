module LatoCms
  # Generates the poster image for a video Media in the background so the
  # upload request is not blocked by ffmpeg processing. Runs once per Media
  # (not per field usage), since the same video can be referenced by many
  # fields. Failures are swallowed by the model (logged as warnings): a
  # missing poster must never break the video.
  class GenerateVideoPosterJob < ApplicationJob
    queue_as :default

    def perform(media_id)
      LatoCms::Media.find_by(id: media_id)&.generate_video_poster!
    end
  end
end
