Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  resources :boxes, only: [:index, :show]
  resources :matches, only: [:show, :new, :create]
  resources :user_match_scores do
    collection do
      get :match
    end
  end
  get "scores", to: "user_match_scores#scores"
end
