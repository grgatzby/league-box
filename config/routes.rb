Rails.application.routes.draw do
  devise_for :users
  # get '/:locale', to: "pages#home"

  scope "(:locale)", locale: /en|fr|nl/ do
    root to: "pages#home"
    get "rules", to: "pages#rules", as: "rules"
    get "staff", to: "pages#staff", as: "staff"
    get "sitemap", to: "pages#sitemap", as: "sitemap"

    resources :preferences, only: %i[new create edit update]

    resources :boxes, only: %i[index show]
    get 'boxese', to: "boxes#index_expanded", as: "index_expanded"
    get 'boxes_csv/boxes', to: "boxes#round_boxes_to_csv", as: "csv_boxes"
    get 'boxes_csv/scores', to: "boxes#round_scores_to_csv", as: "csv_scores"
    get "boxes_list/:id", to: "boxes#show_list", as: "box_list"
    get "my_scores/:id", to: "boxes#my_scores", as: "my_scores"

    resources :matches, only: %i[show edit update new create destroy]
    get 'matches_scores/load_scores', to: "matches#load_scores", as: "load_scores"
    post 'matches_scores/create_scores', to: "matches#create_scores", as: "create_scores"

    resources :user_box_scores, only: %i[index new create]
    get 'user_box_scores/index_league', to: "user_box_scores#index_league", as: "index_league"
    get 'user_box_scores_csv/league_table_round', to: "user_box_scores#round_league_table_to_csv", as: "csv_round_league_table"
    get 'user_box_scores_csv/league_table', to: "user_box_scores#league_table_to_csv", as: "csv_league_table"

    resources :rounds, only: %i[new create edit update]

    resources :chatrooms, only: :show do
      resources :messages, only: :create
    end
    resources :contacts, only: %i[new create]
    get "contacts/sent"

    resources :gallery_images
  end
end
