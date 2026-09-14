module LatoCms
  class MediaController < ApplicationController
    ADMIN_ONLY_ACTIONS = %i[replace_file_action destroy_action].freeze

    before_action { active_sidebar(:lato_cms_media) }
    before_action :authenticate_lato_cms_admin, only: ADMIN_ONLY_ACTIONS

    def index
      media = query_media
      # "Unused" = no page field references it at all: the only media that can
      # be deleted, so it's worth being able to list just those.
      media = media.where.missing(:page_field_media) if params[:usage] == 'unused'

      @media = lato_index_collection(
        media.order(created_at: :desc),
        columns: %i[name media_type usages actions],
        sortable_columns: %i[name media_type created_at],
        searchable_columns: %i[name alt_text title],
        default_sort_by: 'created_at|DESC',
        pagination: 20
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

    # Read-only detail page: the media's own data plus where it's used. Kept
    # apart from the edit form, which is a modal from the index and has no room
    # for a usage list.
    def show
      @media = query_media.find(params[:id])
    end

    def create
      @media = LatoCms::Media.new
    end

    def create_action
      @media = LatoCms::Media.new(create_params.merge(lato_spaces_group_id: @session.get(:spaces_group_id)))

      respond_to do |format|
        if @media.save
          # The JSON branch serves XHR uploads (progress bar, see
          # lato_cms_upload_controller.js). `notify` is sent only by forms that
          # navigate somewhere afterwards, so the flash lands on that page; the
          # media picker uploads in place and asks for no flash.
          flash[:notice] = t('lato_cms.media_created') if params[:notify].present?

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

    # Regenerates one translatable attribute (alt_text or title, see the
    # route constraint) with the LLM. Runs as a Lato::Operation (see
    # GenerateMediaTextJob) rather than inline: an LLM call can take a while,
    # and blocking the request risks timing it out. The admin instead lands on
    # a live progress page.
    def regenerate_text_action
      @media = query_media.find(params[:id])
      attribute = params[:attribute].to_s

      unless @media.image? && LatoCms.config.llm_generates?(attribute)
        respond_to do |format|
          message = t("lato_cms.media_text_regenerate_unavailable")
          format.html { redirect_to lato_cms.media_update_path(@media), alert: message }
          format.json { render json: { error: message }, status: :unprocessable_entity }
        end
        return
      end

      operation = Lato::Operation.generate("LatoCms::GenerateMediaTextJob", { media_id: @media.id, attributes: [attribute] }, @session.user_id)

      if operation.start
        redirect_to lato.operation_path(operation)
      else
        redirect_to lato_cms.media_update_path(@media), alert: t("lato_cms.media_text_regenerate_failed")
      end
    end

    # Replaces the file of an existing media in place, so every page already
    # using it picks up the new file. Kept out of `update_action` (and off
    # `update_params`) on purpose: this is a destructive, admin-only edit to
    # every usage at once, not a metadata change.
    def replace_file_action
      @media = query_media.find(params[:id])
      file = params.dig(:media, :file)

      respond_to do |format|
        if file.present? && @media.replace_file!(file)
          format.html { redirect_to lato_cms.media_show_path(@media), notice: t('lato_cms.media_file_replaced') }
          format.json { render json: @media }
        else
          message = t('lato_cms.media_file_replace_failed')
          format.html { redirect_to lato_cms.media_update_path(@media), alert: message }
          format.json { render json: { error: message }, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      Rails.logger.error("LatoCms: failed to replace file for media #{params[:id]}: #{e.message}")
      message = t('lato_cms.media_file_replace_failed')

      respond_to do |format|
        format.html { redirect_to lato_cms.media_update_path(@media), alert: message }
        format.json { render json: { error: message }, status: :unprocessable_entity }
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
      params.require(:media).permit(:file, :name, :alt_text, :title)
    end

    # :file is intentionally not permitted here: a media can be reused by many
    # fields across many pages, so swapping its file silently changes what
    # renders everywhere it's referenced. That swap is possible, but only
    # through the explicit, admin-only `replace_file_action`.
    def update_params
      translation_keys = LatoCms::Media::TRANSLATABLE_ATTRIBUTES.product(LatoCms.config.locales).map { |attribute, locale| :"#{attribute}_#{locale}" }
      params.require(:media).permit(:name, *translation_keys)
    end
  end
end
