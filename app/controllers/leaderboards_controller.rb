class LeaderboardsController < ApplicationController
  before_action :set_group
  before_action :authorize_member!

  def show
    @rankings = @group.players
      .left_joins(:session_results)
      .select("players.*, COALESCE(SUM(session_results.amount), 0) AS total_amount, COUNT(session_results.id) AS session_count")
      .group("players.id")
      .order("total_amount DESC")
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end
end
