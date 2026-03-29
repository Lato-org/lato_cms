Rails.application.routes.draw do
  mount Lato::Engine => "/lato"
  mount LatoSpaces::Engine => "/lato_spaces"
  mount LatoCms::Engine => "/lato_cms"

  root 'application#index'

  get 'documentation', to: 'application#documentation', as: :documentation
end
