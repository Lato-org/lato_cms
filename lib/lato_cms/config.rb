module LatoCms
  # Config
  # This class contains the default configuration of the engine.
  ##
  class Config
    attr_accessor :locales, :templates_path, :admin_roles, :llm_api_url, :llm_model, :llm_api_key

    def initialize
      @locales = [:en]
      @templates_path = 'config/lato_cms'

      # Admin roles exposed on Lato::User#lato_cms_admin_role and rendered
      # as a select by lato_users. Ordered map of role key => integer value;
      # labels are resolved via i18n (lato_cms.admin_roles.<key>).
      # `operator` has read/edit access; `admin` also manages pages
      # (create, update, delete) and translation links.
      @admin_roles = { none: 0, operator: 1, admin: 2 }

      # Optional OpenAI-compatible endpoint used to auto-generate alt text
      # for uploaded images (see LatoCms::Media#generate_alt_text!). All
      # three must be set for the feature to activate; unset by default.
      @llm_api_url = nil
      @llm_model = nil
      @llm_api_key = nil
    end

    def llm_configured?
      llm_api_url.present? && llm_model.present? && llm_api_key.present?
    end
  end
end