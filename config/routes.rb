Rails.application.routes.draw do
  devise_for :users
  # get '/:locale', to: "pages#home"

  scope "(:locale)", locale: /en|fr|nl/ do
    root to: "pages#home"
    get "rules", to: "pages#rules", as: "rules"
    get "staff", to: "pages#staff", as: "staff"
    get "sitemap", to: "pages#sitemap", as: "sitemap"

    get 'boxes/boxes_to_csv', to: "boxes#league_boxes_to_csv", as: "csv_boxes"
    get "boxes-list/:id", to: "boxes#show_list", as: "box_list"
    get "my_scores/:id", to: "boxes#my_scores", as: "my_scores"
    resources :boxes, only: %i[index show]

    resources :matches, only: %i[show edit update new create destroy]

    resources :user_box_scores, only: %i[index new create]
    get 'user_box_scores/index_year', to: "user_box_scores#index_year", as: "index_year"
    get 'user_box_scores/league_to_csv', to: "user_box_scores#league_table_to_csv", as: "csv_league"
    get 'user_box_scores/league_year_to_csv', to: "user_box_scores#league_year_to_csv", as: "csv_league_year"

    resources :rounds, only: %i[new create]

    resources :chatrooms, only: :show do
      resources :messages, only: :create
    end
    resources :contacts, only: %i[new create]
    get "contacts/sent"
  end
end
