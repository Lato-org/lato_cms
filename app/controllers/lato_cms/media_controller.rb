module LatoCms
  class MediaController < ApplicationController
    ADMIN_ONLY_ACTIONS = %i[destroy_action].freeze

    before_action { active_sidebar(:lato_cms_media) }
    before_action :authenticate_lato_cms_admin, only: ADMIN_ONLY_ACTIONS

    def index
      @media = lato_index_collection(
        query_media.order(created_at: :desc),
        columns: %i[name media_type actions],
        sortable_columns: %i[name media_type created_at],
        searchable_columns: %i[name alt_text],
        default_sort_by: 'created_at|DESC',
        pagination: 24
      )
    end

    # Searchable/filterable grid used inside the field media picker modal
    # (distinct from `index`, which is the full standalone library page).
    def picker_action
      media = query_media
      media = media.of_type(params[:type]) if params[:type].present?
      media = media.where('LOWER(lato_cms_media.name) LIKE :q', q: "%#{params[:q].to_s.downcase}%") if params[:q].present?

      @media = media.order(created_at: :desc).page(params[:page]).per(24)
    end

    def create
      @media = LatoCms::Media.new
    end

    def create_action
      @media = LatoCms::Media.new(create_params.merge(lato_spaces_group_id: @session.get(:spaces_group_id)))

      respond_to do |format|
        if @media.save
          format.html { redirect_to lato_cms.media_path, notice: t('lato_cms.media_created') }
          format.json { render json: @media }
        else
          format.html { render :create, status: :unprocessable_entity }
          format.json { render json: @media.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      @media = query_media.find(params[:id])
    end

    def update_action
      @media = query_media.find(params[:id])

      respond_to do |format|
        if @media.update(update_params)
          format.html { redirect_to lato_cms.media_path, notice: t('lato_cms.media_updated') }
          format.json { render json: @media }
        else
          format.html { render :update, status: :unprocessable_entity }
          format.json { render json: @media.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy_action
      @media = query_media.find(params[:id])
      in_use = @media.usage_count.positive?
      force = ActiveModel::Type::Boolean.new.cast(params[:force])

      respond_to do |format|
        if (!in_use || force) && @media.destroy
          format.html { redirect_to lato_cms.media_path, notice: t('lato_cms.media_deleted') }
          format.json { render json: { message: t('lato_cms.media_deleted') } }
        else
          message = in_use ? t('lato_cms.media_delete_in_use', count: @media.usage_count) : t('lato_cms.media_delete_failed')
          format.html { redirect_to lato_cms.media_path, alert: message }
          format.json { render json: { error: message, usage_count: @media.usage_count }, status: :unprocessable_entity }
        end
      end
    end

    private

    def create_params
      params.require(:media).permit(:file, :name, :alt_text)
    end

    # :file is intentionally not permitted here: the underlying file is
    # immutable once a Media exists (it can be reused by many fields across
    # many pages, so replacing it in place would silently change what renders
    # everywhere it's referenced). A different file means a new Media.
    def update_params
      params.require(:media).permit(:name, :alt_text)
    end
  end
end
