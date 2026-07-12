module LatoCms
  # Config
  # This class contains the default configuration of the engine.
  ##
  class Config
    attr_accessor :locales, :templates_path, :admin_roles

    def initialize
      @locales = [:en]
      @templates_path = 'config/lato_cms'

      # Admin roles exposed on Lato::User#lato_cms_admin_role and rendered
      # as a select by lato_users. Ordered map of role key => integer value;
      # labels are resolved via i18n (lato_cms.admin_roles.<key>).
      # `operator` has read/edit access; `admin` also manages pages
      # (create, update, delete) and translation links.
      @admin_roles = { none: 0, operator: 1, admin: 2 }
    end
  end
end