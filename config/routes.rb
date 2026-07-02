Rails.application.routes.draw do
  root "signups#new"
  get  "/signup",         to: "signups#new",     as: :signup
  post "/signup",         to: "signups#create"
  get  "/signup/success", to: "signups#success", as: :signup_success

  get "up" => "rails/health#show", as: :rails_health_check
end
