Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  get "overview", to: "pages#overview", as: "overview"
  get "staff", to: "pages#staff", as: "staff"

  resources :boxes, only: [:index, :show]
  get "boxes-list/:id", to: "boxes#show_list", as: "box_list"
  get "boxes_referee/:id", to: "boxes#show_referee", as: "box_referee"
  get "manage_my_box/:id", to: "boxes#manage_my_box", as: "manage_my_box"
  resources :matches, only: [:show, :new, :create, :destroy]
  resources :user_box_scores, only: [:index, :new, :create]
  resources :rounds, only: [:new, :create]
  resources :user_match_scores do
    collection do
      get :edit_both
      put :update
    end
  end
end
