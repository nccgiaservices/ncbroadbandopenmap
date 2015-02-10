Rails.application.routes.draw do

  resources :maps, only: [:index, :show]

  root to: "maps#index"

  get 'provider_service(.:format)' => 'maps#providers', :as => :provider_service

  get 'style(.:format)' => 'maps#styles', :as => :style

  get 'district(.:format)' => 'maps#district', :as => :district

  devise_for :user_profiles, ActiveAdmin::Devise.config

  ActiveAdmin.routes(self)

end
