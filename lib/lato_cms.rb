require "lato_cms/version"
require "lato_cms/engine"
require "lato_cms/config"

module LatoCms
  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
    end
  end
end
