module LatoCms
  class ApplicationController < Lato::ApplicationController
    include LatoSpaces::Groupable
    layout 'lato/application'
    before_action :authenticate_session
    before_action :authenticate_group
    before_action :authenticate_lato_cms_access
    before_action { active_sidebar(:lato_cms); active_navbar(:lato_cms) }

    helper_method :lato_cms_admin?

    def index
      redirect_to lato_cms.pages_path
    end

    protected

    def query_pages
      @query_pages ||= LatoCms::Page.for_lato_spaces_group(@session.get(:spaces_group_id))
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

    # Exposed to views to conditionally render admin-only controls.
    def lato_cms_admin?
      @session.user&.lato_cms_admin? || false
    end
  end
end