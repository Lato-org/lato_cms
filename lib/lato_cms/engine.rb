module LatoCms
  class Engine < ::Rails::Engine
    isolate_namespace LatoCms

    initializer 'lato_cms.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
    end

    initializer "lato_cms.precompile" do |app|
      app.config.assets.precompile << "lato_cms_manifest.js"
    end
  end
end
