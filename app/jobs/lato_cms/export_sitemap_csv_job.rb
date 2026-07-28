require 'csv'

module LatoCms
  # Exports every page across every locale of a spaces group as a CSV sitemap.
  # Runs as a Lato::Operation so large sites don't block the request.
  class ExportSitemapCsvJob < Lato::ApplicationJob
    def perform(params = {})
      params = params.with_indifferent_access
      pages = LatoCms::Page.for_lato_spaces_group(params[:lato_spaces_group_id]).order(:locale, :permalink)

      file_path = Rails.root.join('tmp', "sitemap_#{SecureRandom.hex(8)}.csv")
      generate_csv(file_path, pages)

      return file_path unless operation?

      save_operation_output_file(file_path)
      save_operation_output_message(I18n.t('lato_cms.sitemap_export_message', count: pages.count))
    ensure
      File.delete(file_path) if file_path && File.exist?(file_path)
    end

    private

    def generate_csv(file_path, pages)
      CSV.open(file_path, 'wb') do |csv|
        csv << %w[locale title permalink frontend_url]
        pages.find_each do |page|
          csv << [page.locale, page.title, page.permalink, page.frontend_url]
        end
      end
    end
  end
end
