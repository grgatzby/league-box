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
  resources :user_box_scores, only: [:index]
  get "mybox/:id", to: "boxes#mybox", as: "mybox"
  get "boxes-list/:id", to: "boxes#show_list", as: "show_list"
  get "scores", to: "user_match_scores#scores"
  get "overview", to: "pages#overview", as: "overview"
end
