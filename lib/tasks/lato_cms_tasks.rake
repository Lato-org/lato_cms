require 'fileutils'

namespace :lato_cms do
  namespace :install do
    desc 'Install Lato CMS engine and create example templates'
    # Usage: rails lato_cms:install:application
    task application: :environment do
      base_path = Rails.root.join(LatoCms.config.templates_path)
      templates_path = base_path.join('templates')
      components_path = base_path.join('components')

      FileUtils.mkdir_p(templates_path)
      FileUtils.mkdir_p(components_path)

      # Create example component
      component_file = components_path.join('hero.yml')
      unless File.exist?(component_file)
        File.write(component_file, <<~YAML)
          id: hero
          name: Hero Section
          fields:
            title:
              name: Title
              type: string
              required: true
              settings:
                placeholder: "Enter the hero title"
            subtitle:
              name: Subtitle
              type: textarea
              required: false
              settings:
                rows: 3
                placeholder: "Enter a subtitle"
            image:
              name: Background Image
              type: image
              required: false
        YAML
        puts "Created #{component_file}"
      else
        puts "Skipped #{component_file} (already exists)"
      end

      # Create example template
      template_file = templates_path.join('homepage.yml')
      unless File.exist?(template_file)
        File.write(template_file, <<~YAML)
          id: homepage
          name: Homepage
          components:
            hero_section:
              component_id: hero
              name: Hero Section
        YAML
        puts "Created #{template_file}"
      else
        puts "Skipped #{template_file} (already exists)"
      end

      puts ""
      puts "Lato CMS templates installed in #{base_path}"
      puts "  Templates: #{templates_path}"
      puts "  Components: #{components_path}"
    end
  end

  namespace :generate do
    desc 'Generate a new template YAML file'
    # Usage: rails "lato_cms:generate:template[template_name]"
    task :template, [:name] => :environment do |_t, args|
      name = args[:name]
      abort "Usage: rails \"lato_cms:generate:template[template_name]\"" if name.blank?

      templates_path = Rails.root.join(LatoCms.config.templates_path, 'templates')
      FileUtils.mkdir_p(templates_path)

      id = name.parameterize(separator: '_')
      file = templates_path.join("#{id}.yml")

      abort "Template file already exists: #{file}" if File.exist?(file)

      File.write(file, <<~YAML)
        id: #{id}
        name: #{name.titleize}
        components: {}
      YAML

      puts "Created template: #{file}"
    end

    desc 'Generate a new component YAML file'
    # Usage: rails "lato_cms:generate:component[component_name,field_id:type,field_id:type]"
    task :component, [:name] => :environment do |_t, args|
      name = args[:name]
      abort "Usage: rails \"lato_cms:generate:component[component_name,field_id:type,...]\"" if name.blank?

      components_path = Rails.root.join(LatoCms.config.templates_path, 'components')
      FileUtils.mkdir_p(components_path)

      id = name.parameterize(separator: '_')
      file = components_path.join("#{id}.yml")

      abort "Component file already exists: #{file}" if File.exist?(file)

      # `custom` is left out: it needs a `render` partial path, which a
      # field_id:type pair cannot carry (see the custom_field task).
      valid_types = LatoCms::PagesHelper::BUILTIN_FIELD_TYPES

      # Parse field pairs from extra args. An unknown type aborts instead of
      # silently becoming a string field.
      fields = {}
      (args.extras || []).each do |arg|
        parts = arg.split(':')
        abort "Invalid field definition \"#{arg}\": use field_id:type" unless parts.length == 2

        field_id = parts[0].parameterize(separator: '_')
        field_type = parts[1]
        unless valid_types.include?(field_type)
          abort "Unsupported field type \"#{field_type}\" for #{field_id}. Supported: #{valid_types.join(', ')}"
        end

        fields[field_id] = {
          'name' => field_id.humanize,
          'type' => field_type,
          'required' => false
        }
      end

      if fields.empty?
        fields['example_field'] = {
          'name' => 'Example Field',
          'type' => 'string',
          'required' => false
        }
      end

      yaml_content = {
        'id' => id,
        'name' => name.titleize,
        'fields' => fields
      }

      File.write(file, yaml_content.to_yaml)
      puts "Created component: #{file}"
    end

    desc 'Generate custom field partial in host app'
    # Usage: rails "lato_cms:generate:custom_field[field_name]"
    task :custom_field, [:name] => :environment do |_t, args|
      name = args[:name]
      abort "Usage: rails \"lato_cms:generate:custom_field[field_name]\"" if name.blank?

      field_id = name.parameterize(separator: '_')
      views_path = Rails.root.join('app', 'views', 'lato_cms', 'custom_fields')
      FileUtils.mkdir_p(views_path)

      file = views_path.join("_#{field_id}.html.erb")
      abort "Custom field partial already exists: #{file}" if File.exist?(file)

      # Names and ids come from the engine helpers so the field also works
      # inside a repeater (where both carry the item prefix).
      File.write(file, <<~ERB)
        <% label = field_config['name'] || field_id.humanize %>
        <% required = field_config['required'] == true %>
        <% settings = field_config['settings'] || {} %>
        <% current_value = page_field&.value.to_s %>
        <% input_name = lato_cms_field_input_name(field_id, input_name_prefix: local_assigns[:input_name_prefix]) %>
        <% input_id = lato_cms_field_dom_id(field_id, dom_id_prefix: local_assigns[:dom_id_prefix]) %>

        <label class="form-label" for="<%= input_id %>">
          <%= label %><%= ' *' if required %>
        </label>

        <input type="text"
          class="form-control"
          name="<%= input_name %>"
          id="<%= input_id %>"
          value="<%= current_value %>"
          <%= 'required' if required %>
          placeholder="<%= settings['placeholder'] %>">
      ERB

      puts "Created custom field partial: #{file}"
      puts "Use in component YAML:"
      puts "  type: custom"
      puts "  render: lato_cms/custom_fields/#{field_id}"
    end
  end
end
