Rails.application.routes.draw do
  devise_for :users
  # get '/:locale', to: "pages#home"

  scope "(:locale)", locale: /en|fr|nl/ do
    root to: "pages#home"
    get "rules", to: "pages#rules", as: "rules"
    get "staff", to: "pages#staff", as: "staff"
    get "sitemap", to: "pages#sitemap", as: "sitemap"

    resources :boxes, only: [:index, :show]
    get "boxes-list/:id", to: "boxes#show_list", as: "box_list"
    get "boxes_referee/:id", to: "boxes#show_referee", as: "box_referee"
    get "manage_my_box/:id", to: "boxes#manage_my_box", as: "manage_my_box"

    resources :matches, only: [:show, :edit, :update, :new, :create, :destroy]
    resources :user_box_scores, only: [:index, :new, :create]
    resources :rounds, only: [:new, :create]

    resources :chatrooms, only: :show do
      resources :messages, only: :create
    end
    resources :contacts, only: [:new, :create ]
    get "/contacts", to: "contacts#new", as: "contact"
    get "contacts/sent"
  end
end
