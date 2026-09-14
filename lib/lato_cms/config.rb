module LatoCms
  # Config
  # This class contains the default configuration of the engine.
  ##
  class Config
    attr_accessor :locales, :templates_path, :admin_roles, :media_url_mode, :llm_api_url, :llm_model,
                  :llm_api_key, :llm_generate_alt_text, :llm_generate_title, :llm_alt_text_prompt,
                  :llm_title_prompt

    # How the URLs of media files are built (see LatoCms::Media#url).
    # - :redirect — Rails answers 302 with a signed URL that expires; on a
    #   remote service (S3 and friends) the file then comes from the service
    #   itself, which is what you want there.
    # - :proxy — the file is served through the app, with no redirect and with
    #   `Cache-Control: public, immutable`, so browsers and any cache in front
    #   can keep it. On a disk service this is strictly better: the redirect
    #   costs a second request and its target can be cached by nobody.
    MEDIA_URL_MODES = %i[redirect proxy].freeze

    # Placeholders substituted at request time in both default and custom LLM
    # prompts (see LatoCms::Media#llm_prompt):
    # - {languages}: comma-separated LatoCms.config.locales
    # - {urls}: comma-separated frontend URLs of the pages using the media, so
    #   the model can look at where the image is shown ("none" when it isn't
    #   used anywhere yet, e.g. right after upload)
    LLM_PROMPT_VARIABLES = %w[languages urls].freeze

    # Task prompts used when the host app sets no custom one. The response
    # format contract (a JSON object keyed by locale) is appended by the
    # engine to every prompt, custom ones included, so it's not part of these.
    DEFAULT_LLM_PROMPTS = {
      alt_text: "Write a concise, descriptive alt text for this image, for the HTML <img alt> attribute " \
                "(accessibility use, not a caption). The website is published in these languages: {languages}. " \
                "The image is used on these pages, use them as context for what it depicts and why: {urls}.",
      title: "Write a short, human-readable title for this image, for the HTML <img title> attribute " \
             "(a few words, no trailing period, not a full description). The website is published in these " \
             "languages: {languages}. The image is used on these pages, use them as context: {urls}."
    }.freeze

    def initialize
      @locales = [:en]
      @templates_path = "config/lato_cms"

      # Admin roles exposed on Lato::User#lato_cms_admin_role and rendered
      # as a select by lato_users. Ordered map of role key => integer value;
      # labels are resolved via i18n (lato_cms.admin_roles.<key>).
      # `operator` has read/edit access; `admin` also manages pages
      # (create, update, delete) and translation links.
      @admin_roles = { none: 0, operator: 1, admin: 2 }

      # Default is :redirect, which is how it always worked: switching the way
      # every media URL is built is a decision for the host app, not something
      # an upgrade should do on its own. See MEDIA_URL_MODES.
      @media_url_mode = :redirect

      # Optional OpenAI-compatible endpoint used to auto-generate alt text and
      # title for uploaded images (see LatoCms::Media#generate_text!). All
      # three must be set for the feature to activate; unset by default.
      @llm_api_url = nil
      @llm_model = nil
      @llm_api_key = nil

      # Which Media attributes the LLM generates (post-upload and via the
      # "Regenerate with AI" buttons). Both on once an LLM is configured;
      # switch one off to skip it, each costs one LLM call per upload.
      @llm_generate_alt_text = true
      @llm_generate_title = true

      # Custom task prompts, nil falls back to DEFAULT_LLM_PROMPTS. May embed
      # LLM_PROMPT_VARIABLES placeholders.
      @llm_alt_text_prompt = nil
      @llm_title_prompt = nil
    end

    def media_url_proxy?
      media_url_mode.to_sym == :proxy
    end

    def llm_configured?
      llm_api_url.present? && llm_model.present? && llm_api_key.present?
    end

    # Media attributes the LLM generates, as configured. Empty unless an LLM
    # is configured, so callers need a single check.
    def llm_media_attributes
      return [] unless llm_configured?

      { alt_text: llm_generate_alt_text, title: llm_generate_title }.select { |_attribute, enabled| enabled }.keys
    end

    def llm_generates?(attribute)
      llm_media_attributes.include?(attribute.to_sym)
    end

    def llm_prompt(attribute)
      attribute = attribute.to_sym
      public_send("llm_#{attribute}_prompt").presence || DEFAULT_LLM_PROMPTS.fetch(attribute)
    end
  end
end
