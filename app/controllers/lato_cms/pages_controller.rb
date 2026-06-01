module LatoCms
  class PagesController < ApplicationController
    before_action { active_sidebar(:lato_cms_pages) }

    def index
      pages = query_pages
      pages = pages.where(locale: params[:locale]) if params[:locale].present?

      @pages = lato_index_collection(
        pages,
        columns: %i[title permalink locale actions],
        sortable_columns: %i[title permalink locale],
        searchable_columns: %i[title permalink],
        default_sort_by: 'title|ASC',
        pagination: 20
      )
    end

    def show
      @page = query_pages.find(params[:id])
      @page.fields.load
      @template = @page.template
      @template_components = @page.template_components
    end

    def create
      @page = LatoCms::Page.new(locale: LatoCms.config.locales.first.to_s)
    end

    def create_action
      @page = LatoCms::Page.new(create_params.merge(lato_spaces_group_id: @session.get(:spaces_group_id)))

      respond_to do |format|
        if @page.save
          format.html { redirect_to lato_cms.pages_path, notice: t('lato_cms.page_created') }
          format.json { render json: @page }
        else
          format.html { render :create, status: :unprocessable_entity }
          format.json { render json: @page.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      @page = query_pages.find(params[:id])
    end

    def update_action
      @page = query_pages.find(params[:id])

      respond_to do |format|
        if @page.update(update_params)
          format.html { redirect_to lato_cms.pages_show_path(@page), notice: t('lato_cms.page_updated') }
          format.json { render json: @page }
        else
          format.html { render :update, status: :unprocessable_entity }
          format.json { render json: @page.errors, status: :unprocessable_entity }
        end
      end
    end

    def save_fields_action
      @page = query_pages.find(params[:id])

      template_component_id = params[:template_component_id]
      component_id = params[:component_id]
      fields_data = params[:fields] || {}

      component = LatoCms::TemplateManager.find_component(component_id)
      errors = []

      unless @page.component_effectively_enabled?(template_component_id)
        respond_to do |format|
          format.html { redirect_to lato_cms.pages_show_path(@page), alert: t('lato_cms.component_disabled_cannot_save') }
          format.json { render json: { error: t('lato_cms.component_disabled_cannot_save') }, status: :unprocessable_entity }
        end
        return
      end

      fields_data.each do |field_id, field_data|
        field = @page.fields.find_or_initialize_by(
          template_id: @page.template_id,
          template_component_id: template_component_id,
          component_id: component_id,
          field_id: field_id
        )

        field_config = component&.dig('fields', field_id)
        field_type = field_config&.dig('type') || 'string'

        case field_type
        when 'file', 'image'
          field.save if field.new_record?
          if field_data[:files].present?
            Array(field_data[:files]).compact.each { |f| field.files.attach(f) }
          end
          if field_data[:remove_file_ids].present?
            Array(field_data[:remove_file_ids]).reject(&:blank?).each do |file_id_to_remove|
              field.files.find { |f| f.id == file_id_to_remove.to_i }&.purge
            end
          end
        when 'gallery'
          field.save if field.new_record?
          if field_data[:files].present?
            Array(field_data[:files]).compact.each { |f| field.files.attach(f) }
          end
          if field_data[:remove_file_ids].present?
            Array(field_data[:remove_file_ids]).reject(&:blank?).each do |file_id_to_remove|
              field.files.find { |f| f.id == file_id_to_remove.to_i }&.purge
            end
          end
          # Persist order: existing IDs in dragged order + any new file IDs appended at end
          order = Array(field_data[:order]).reject(&:blank?).map(&:to_s)
          all_ids = field.files.reload.map { |f| f.id.to_s }
          sorted = order.select { |id| all_ids.include?(id) }
          new_ids = all_ids - sorted
          field.value = (sorted + new_ids).to_json
        when 'multiselect'
          value = field_data[:value]
          value = Array(value).reject(&:blank?)
          field.value = value.to_json
        else
          raw_value = field_data.is_a?(ActionController::Parameters) ? field_data[:value] : field_data
          field.value = raw_value.to_s.presence
        end

        unless field.save
          errors << { field_id: field_id, errors: field.errors.full_messages }
        end
      end

      respond_to do |format|
        if errors.empty?
          format.html { redirect_to lato_cms.pages_show_path(@page), notice: t('lato_cms.fields_saved') }
          format.json { render json: { message: t('lato_cms.fields_saved') } }
        else
          error_messages = errors.map { |e| "#{e[:field_id]}: #{e[:errors].join(', ')}" }.join('; ')
          format.html { redirect_to lato_cms.pages_show_path(@page), alert: error_messages }
          format.json { render json: { errors: errors }, status: :unprocessable_entity }
        end
      end
    end

    def toggle_component_action
      @page = query_pages.find(params[:id])
      template_component_id = params[:template_component_id].to_s
      enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])

      if @page.component_required?(template_component_id)
        respond_to do |format|
          format.html { redirect_to lato_cms.pages_show_path(@page), alert: t('lato_cms.component_required_cannot_disable') }
          format.json { render json: { error: t('lato_cms.component_required_cannot_disable') }, status: :unprocessable_entity }
        end
        return
      end

      @page.set_component_enabled(template_component_id, enabled)

      respond_to do |format|
        if @page.save
          format.html { redirect_to lato_cms.pages_show_path(@page), notice: t('lato_cms.component_state_updated') }
          format.json { render json: { message: t('lato_cms.component_state_updated') } }
        else
          format.html { redirect_to lato_cms.pages_show_path(@page), alert: @page.errors.full_messages.to_sentence }
          format.json { render json: { errors: @page.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy_action
      @page = query_pages.find(params[:id])

      respond_to do |format|
        if @page.destroy
          format.html { redirect_to lato_cms.pages_path, notice: t('lato_cms.page_deleted') }
          format.json { render json: { message: t('lato_cms.page_deleted') } }
        else
          format.html { redirect_to lato_cms.pages_path, alert: t('lato_cms.page_delete_failed') }
          format.json { render json: { error: t('lato_cms.page_delete_failed') }, status: :unprocessable_entity }
        end
      end
    end

    private

    def create_params
      params.require(:page).permit(:title, :locale)
    end

    def update_params
      params.require(:page).permit(:title, :permalink, :frontend_url, :template_id)
    end
  end
end
