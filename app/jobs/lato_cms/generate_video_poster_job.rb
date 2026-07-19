module LatoCms
  # Generates the poster image for a video field in the background so the save
  # request is not blocked by ffmpeg processing. Failures are swallowed by the
  # model (logged as warnings): a missing poster must never break the field.
  class GenerateVideoPosterJob < ApplicationJob
    queue_as :default

    def perform(page_field_id)
      LatoCms::PageField.find_by(id: page_field_id)&.generate_video_poster!
    end
  end
end
