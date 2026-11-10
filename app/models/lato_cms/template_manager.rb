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
        cached_yaml_files(templates_path)
      end

      def components
        cached_yaml_files(components_path)
      end

      def find_template(template_id)
        return nil if template_id.blank?
        templates.find { |t| t['id'] == template_id.to_s }
      end

      def find_component(component_id)
        return nil if component_id.blank?
        components.find { |c| c['id'] == component_id.to_s }
      end

      # The field definitions of a template component, resolved through the
      # template (template -> template component -> component). This is the
      # authoritative source for a field's type: the component id stored on a
      # PageField, or sent by a client, is never trusted to pick it.
      def find_template_component_fields(template_id, template_component_id)
        component_id = find_template(template_id)&.dig('components', template_component_id.to_s, 'component_id')
        find_component(component_id)&.dig('fields')
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
            required: tc_config['required'] == true,
            repeater: tc_config['repeater'] == true || tc_config['repeatable'] == true,
            settings: tc_config['settings'] || {},
            component: component,
            fields: component ? (component['fields'] || {}) : {}
          }
        end
      end

      def reset_cache!
        @cache = {}
      end

      private

      # Parsed YAML is kept per process: every field read (type, name,
      # settings) goes through here, so re-reading the files each time cost
      # hundreds of parses per request, on a public endpoint too. When code
      # reloading is on (development) the cache is keyed by the files' mtimes,
      # so edited templates show up without a restart. Entries are deep-frozen
      # because they are shared by every caller.
      def cached_yaml_files(path)
        @cache ||= {}
        fingerprint = reloading? ? yaml_fingerprint(path) : nil
        entry = @cache[path.to_s]
        return entry[:data] if entry && entry[:fingerprint] == fingerprint

        data = deep_freeze(load_yaml_files(path))
        @cache[path.to_s] = { fingerprint: fingerprint, data: data }
        data
      end

      def reloading?
        Rails.application.config.respond_to?(:enable_reloading) && Rails.application.config.enable_reloading
      end

      def yaml_fingerprint(path)
        Dir.glob(File.join(path, '*.yml')).sort.map { |file| [file, File.mtime(file).to_f] }
      end

      def deep_freeze(object)
        case object
        when Hash then object.each_value { |value| deep_freeze(value) }
        when Array then object.each { |value| deep_freeze(value) }
        end
        object.freeze
      end

      def load_yaml_files(path)
        return [] unless Dir.exist?(path)

        Dir.glob(File.join(path, '*.yml')).sort.filter_map do |file|
          YAML.load_file(file)
        rescue Psych::SyntaxError => e
          Rails.logger.error("LatoCms: Failed to parse YAML file #{file}: #{e.message}")
          nil
        end
      end
    end
  end
end
