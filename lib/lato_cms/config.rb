module LatoCms
  # Config
  # This class contains the default configuration of the engine.
  ##
  class Config
    attr_accessor :locales, :templates_path

    def initialize
      @locales = [:en]
      @templates_path = 'config/lato_cms'
    end
  end
end