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
    delete ':id', to: 'pages#destroy_action', as: :pages_destroy_action
  end
end
