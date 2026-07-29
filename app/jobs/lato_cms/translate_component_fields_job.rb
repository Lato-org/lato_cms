module LatoCms
  # Translates a just-cloned component's free-text fields via the configured
  # LLM, as a Lato::Operation so a slow/unreachable LLM never blocks the
  # clone request (see PagesController#clone_component_action). The verbatim
  # clone this follows has already happened synchronously and is not undone
  # if this fails.
  class TranslateComponentFieldsJob < Lato::ApplicationJob
    def perform(params = {})
      params = params.with_indifferent_access
      page = LatoCms::Page.find(params[:page_id])
      page.translate_component_fields!(params[:template_component_id])

      save_operation_output_message(I18n.t('lato_cms.component_clone_translated')) if operation?
    end
  end
end
