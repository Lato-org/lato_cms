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
      end
    end
  end
end
