module LatoCms
  class TemplateManager
    class << self
      def templates_path
        Rails.root.join(LatoCms.config.templates_path, 'templates')
      end

      def components_path
        Rails.root.join(LatoCms.config.templates_path, 'components')
      end

      def templates
        load_yaml_files(templates_path)
      end

      def components
        load_yaml_files(components_path)
      end

      def find_template(template_id)
        return nil if template_id.blank?
        templates.find { |t| t['id'] == template_id.to_s }
      end

      def find_component(component_id)
        return nil if component_id.blank?
        components.find { |c| c['id'] == component_id.to_s }
      end

      def template_options
        templates.map { |t| [t['name'], t['id']] }
      end

      def resolve_template_components(template)
        return [] unless template && template['components']

        template['components'].map do |tc_id, tc_config|
          component = find_component(tc_config['component_id'])
          {
            template_component_id: tc_id.to_s,
            component_id: tc_config['component_id'].to_s,
            name: tc_config['name'].presence || component&.dig('name') || tc_config['component_id'].to_s.humanize,
            component: component,
            fields: component ? (component['fields'] || {}) : {}
          }
        end
      end

      private

      def load_yaml_files(path)
        return [] unless Dir.exist?(path)

        Dir.glob(File.join(path, '*.yml')).filter_map do |file|
          YAML.load_file(file)
        rescue Psych::SyntaxError => e
          Rails.logger.error("LatoCms: Failed to parse YAML file #{file}: #{e.message}")
          nil
        end
      end
    end
  end
end
