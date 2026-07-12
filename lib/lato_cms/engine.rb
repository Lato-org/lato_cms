module LatoCms
  class Engine < ::Rails::Engine
    isolate_namespace LatoCms

    initializer 'lato_cms.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
    end

    initializer "lato_cms.precompile" do |app|
      app.config.assets.precompile << "lato_cms_manifest.js"
    end

    # Expose the CMS admin role options on the shared Lato::User model.
    # lato_users (when mounted) discovers the `lato_cms_admin_role` column by
    # convention and calls this method to build the role selector. Defined
    # here so it works regardless of whether lato_users is installed.
    config.to_prepare do
      Lato::User.class_eval do
        # Role options for the lato_cms_admin_role permission.
        # Returns [[label, value], ...] with labels resolved at call time.
        def self.lato_cms_admin_role_options
          LatoCms.config.admin_roles.map do |key, value|
            [I18n.t("lato_cms.admin_roles.#{key}"), value]
          end
        end

        # True when the user can access the CMS section (operator or admin).
        def lato_cms_access?
          lato_cms_admin_role.to_i.positive?
        end

        # True when the user has the admin role: full page management
        # (create, update, delete) and translation links.
        def lato_cms_admin?
          lato_cms_admin_role.to_i >= LatoCms.config.admin_roles.fetch(:admin, 0)
        end
      end
    end
  end
end
