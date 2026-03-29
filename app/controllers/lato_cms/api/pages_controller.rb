module LatoCms
  module Api
    class PagesController < ActionController::API
      before_action :authenticate_lato_spaces_group
      before_action :set_page, only: [:show]

      def index
        pages = LatoCms::Page.for_lato_spaces_group(@lato_spaces_group_id).order(title: :asc)
        pages = pages.where(locale: params[:locale]) if params[:locale].present?
        render json: pages.map(&:as_json)
      end

      def show
        @page.fields.load
        render json: @page.as_json(include_fields: true)
      end

      private

      def authenticate_lato_spaces_group
        @lato_spaces_group_id = params[:group_id]
        if @lato_spaces_group_id.blank?
          render json: { error: 'group_id parameter is required' }, status: :bad_request
          return
        end

        true
      end

      def set_page
        id = params[:id]
        @page = id.match?(/\A\d+\z/) ? LatoCms::Page.for_lato_spaces_group(@lato_spaces_group_id).find(id) : LatoCms::Page.for_lato_spaces_group(@lato_spaces_group_id).find_by!(permalink: "/#{id.delete_prefix('/')}")
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t('lato_cms.api_page_not_found') }, status: :not_found
      end
    end
  end
end
