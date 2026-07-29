module LatoCms
  # Generates alt text for an image Media via an OpenAI-compatible LLM.
  # Doubles as a plain background job (automatic post-upload call site, see
  # Media#enqueue_alt_text_generation: fire-and-forget, best effort, never
  # blocks the upload) and as a Lato::Operation-backed job (the "Regenerate
  # with AI" admin action, see MediaController#regenerate_alt_text_action:
  # the admin is watching, so failures should surface instead of being
  # swallowed). Inheriting Lato::ApplicationJob makes both work from the
  # same perform: `operation?` is only true when a `_operation_id` was
  # injected by Lato::Operation#start.
  class GenerateAltTextJob < Lato::ApplicationJob
    def perform(params = {})
      params = params.with_indifferent_access
      media = LatoCms::Media.find_by(id: params[:media_id])
      return unless media

      media.generate_alt_text!(raise_on_error: operation?)
      save_operation_output_message(I18n.t('lato_cms.media_alt_text_regenerated')) if operation?
    end
  end
end
