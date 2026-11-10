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
          csv << [page.locale, page.title, page.permalink, page.frontend_url].map { |value| self.class.neutralize_formula(value) }
        end
      end
    end

    # Spreadsheets run a cell starting with = + - @ (or a tab/CR before one)
    # as a formula: a page titled =HYPERLINK(...) would execute when the
    # export is opened. A leading apostrophe makes it plain text.
    def self.neutralize_formula(value)
      value.is_a?(String) && value.start_with?('=', '+', '-', '@', "\t", "\r") ? "'#{value}" : value
    end
  end
end
