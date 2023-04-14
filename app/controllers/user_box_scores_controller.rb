class UserBoxScoresController < ApplicationController
  def index
    @scores = UserBoxScore.all
  end
end
