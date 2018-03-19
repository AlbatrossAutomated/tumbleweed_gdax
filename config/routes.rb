Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :settings_estimator, only: [:create]

  # stays last
  # root 'settings_estimator#new'
end
