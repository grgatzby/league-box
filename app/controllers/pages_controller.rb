class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :overview, :staff]

  def staff
    if current_user == @admin
      @managers = User.where(role: "manager")
    end
  end
end
