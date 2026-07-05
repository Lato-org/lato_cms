LatoCms::Engine.routes.draw do
  root 'application#index'

  namespace :api do
    scope :pages do
      get '', to: 'pages#index', as: :pages
      get '*id', to: 'pages#show', as: :pages_show
    end
  end

  scope :pages do
    get '', to: 'pages#index', as: :pages
    get 'create', to: 'pages#create', as: :pages_create
    post 'create', to: 'pages#create_action', as: :pages_create_action
    get ':id', to: 'pages#show', as: :pages_show
    get ':id/update', to: 'pages#update', as: :pages_update
    patch ':id/update', to: 'pages#update_action', as: :pages_update_action
    post ':id/fields', to: 'pages#save_fields_action', as: :pages_save_fields_action
    patch ':id/components/:template_component_id/toggle', to: 'pages#toggle_component_action', as: :pages_toggle_component_action
    post ':id/components/:template_component_id/clone', to: 'pages#clone_component_action', as: :pages_clone_component_action
    get ':id/translations', to: 'pages#translations', as: :pages_translations
    post ':id/translations', to: 'pages#link_translation_action', as: :pages_link_translation_action
    delete ':id/translations', to: 'pages#unlink_translation_action', as: :pages_unlink_translation_action
    delete ':id', to: 'pages#destroy_action', as: :pages_destroy_action
  end
end
