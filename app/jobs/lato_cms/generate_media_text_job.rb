module LatoCms
  # Generates alt text and/or title for an image Media via an OpenAI-compatible
  # LLM in a single call, whatever the number of attributes: the image travels
  # in the request, so one call per attribute meant uploading it twice (see
  # Media#generate_texts!). `attributes` defaults to every attribute enabled in
  # config, which is what both the automatic post-upload run and the
  # "Regenerate with AI" action ask for.
  #
  # Doubles as a plain background job (post-upload call site, see
  # Media#enqueue_text_generation: fire-and-forget, best effort, never blocks
  # the upload) and as a Lato::Operation-backed job (the admin actions, see
  # MediaController#regenerate_text_action: the admin is watching, so failures
  # should surface instead of being swallowed). Inheriting Lato::ApplicationJob
  # makes both work from the same perform: `operation?` is only true when a
  # `_operation_id` was injected by Lato::Operation#start.
  class GenerateMediaTextJob < Lato::ApplicationJob
    def perform(params = {})
      params = params.with_indifferent_access
      media = LatoCms::Media.find_by(id: params[:media_id])
      return unless media

      attributes = Array(params[:attributes]).presence || LatoCms.config.llm_media_attributes
      media.generate_texts!(attributes, raise_on_error: operation?)
      save_operation_output_message(I18n.t("lato_cms.media_text_regenerated")) if operation?
    end
  end
end
