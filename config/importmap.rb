pin "lato_cms/application", to: "lato_cms/application.js"
pin_all_from LatoCms::Engine.root.join("app/assets/javascripts/lato_cms/controllers"), under: "controllers", to: "lato_cms/controllers"
