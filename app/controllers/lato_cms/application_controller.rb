module LatoCms
  class ApplicationController < Lato::ApplicationController
    include LatoSpaces::Groupable
    layout 'lato/application'
    before_action :authenticate_session
    before_action :authenticate_group
    before_action :authenticate_lato_cms_access
    before_action { active_sidebar(:lato_cms); active_navbar(:lato_cms) }

    helper_method :lato_cms_admin?

    EXPENSIVE_ACTIONS_RATE_LIMIT = 10

    # LLM calls and exports run as background operations that cost money or
    # I/O. Operators may start them, but not in unbounded bursts: at most
    # EXPENSIVE_ACTIONS_RATE_LIMIT per user per minute, counted in Rails.cache
    # (a per-process memory store only limits per process, a null store not
    # at all).
    def self.rate_limit_expensive_actions(*actions)
      rate_limit to: EXPENSIVE_ACTIONS_RATE_LIMIT, within: 1.minute, only: actions, store: Rails.cache,
        name: 'lato_cms_expensive', by: -> { @session.user_id }, with: -> { render_rate_limited }
    end

    def index
      redirect_to lato_cms.pages_path
    end

    protected

    def query_pages
      @query_pages ||= LatoCms::Page.for_lato_spaces_group(@session.get(:spaces_group_id))
    end

    def query_media
      @query_media ||= LatoCms::Media.for_lato_spaces_group(@session.get(:spaces_group_id))
    end

    # Section-level guard: any CMS role (operator or admin) may enter.
    def authenticate_lato_cms_access
      return true if @session.user&.lato_cms_access?

      redirect_to lato.root_path, alert: t('lato_cms.unauthorized_section')
    end

    # Action-level guard for page management and translation links: admin only.
    def authenticate_lato_cms_admin
      return true if lato_cms_admin?

      redirect_to lato_cms.pages_path, alert: t('lato_cms.unauthorized_action')
    end

    def render_rate_limited
      message = t('lato_cms.rate_limited')

      respond_to do |format|
        format.html { redirect_back fallback_location: lato_cms.pages_path, alert: message }
        format.json { render json: { error: message }, status: :too_many_requests }
        format.any { head :too_many_requests }
      end
    end

    # Exposed to views to conditionally render admin-only controls.
    def lato_cms_admin?
      @session.user&.lato_cms_admin? || false
    end
  end
end
