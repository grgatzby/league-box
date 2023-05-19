class RoundsController < ApplicationController
  def new
    @current_round = current_round(current_user)
    @boxes = @current_round.boxes.sort
    @message = "Select box move, for example:<br />
                2 = two boxes up,<br />
                1 = one box up,<br />
                -1 = one box down,<br />
                -2 = two boxes down.<br /><br />
                Select 99 to remove user."

    @new_round = Round.new
    @new_round.boxes.build.user_box_scores.build
  end
end
