class UserBoxScoresController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  def index
    club = Club.last
    @box_scores = UserBoxScore.all
  end
end
