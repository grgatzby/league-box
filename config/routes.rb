Rails.application.routes.draw do
  devise_for :users
  # get '/:locale', to: "pages#home"

  scope "(:locale)", locale: /en|fr|nl/ do
    root to: "pages#home"
    get "rules", to: "pages#rules", as: "rules"
    get "staff", to: "pages#staff", as: "staff"
    get "sitemap", to: "pages#sitemap", as: "sitemap"

    resources :boxes, only: %i[index show]
    get "boxes-list/:id", to: "boxes#show_list", as: "box_list"
    get "boxes_referee/:id", to: "boxes#show_referee", as: "box_referee"
    get "my_box/:id", to: "boxes#my_box", as: "my_box"

    resources :matches, only: %i[show edit update new create destroy]

    resources :user_box_scores, only: %i[index new create]
    get 'user_box_scores/download_csv', to: "user_box_scores#download_csv", as: "download"

    resources :rounds, only: %i[new create]

    resources :chatrooms, only: :show do
      resources :messages, only: :create
    end
    resources :contacts, only: %i[new create]
    get "contacts/sent"
  end
end
