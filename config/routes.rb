Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  resources :boxes, only: [:index, :show]
  resources :matches, only: [:show, :new, :create, :destroy]
  resources :user_match_scores do
    collection do
      # get :match, :edit_both
      get :edit_both
      put :update
    end
  end
  resources :user_box_scores, only: [:index]
  get "manage_my_box/:id", to: "boxes#manage_my_box", as: "manage_my_box"
  get "show_manager/:id", to: "boxes#show_manager", as: "box_manager"
  get "boxes-list/:id", to: "boxes#show_list", as: "box_list"
  # get "scores", to: "user_match_scores#scores"
  get "overview", to: "pages#overview", as: "overview"
  get "staff", to: "pages#staff", as: "staff"
end
