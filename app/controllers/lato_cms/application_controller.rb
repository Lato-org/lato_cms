module LatoCms
  class ApplicationController < Lato::ApplicationController
    include LatoSpaces::Groupable
    layout 'lato/application'
    before_action :authenticate_session
    before_action :authenticate_group
    before_action :authenticate_lato_cms_admin
    before_action { active_sidebar(:lato_cms); active_navbar(:lato_cms) }

    def index
      redirect_to lato_cms.pages_path
    end

    protected

    def query_pages
      @query_pages ||= LatoCms::Page.for_lato_spaces_group(@session.get(:spaces_group_id))
    end

    def authenticate_lato_cms_admin
      return true if @session.user&.lato_cms_admin

      redirect_to lato.root_path, alert: t('lato_cms.unauthorized_section')
    end
  end
end