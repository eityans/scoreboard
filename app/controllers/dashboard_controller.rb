class DashboardController < ApplicationController
  def show
    @groups = current_user.groups.includes(:users, :poker_sessions)
    @recent_sessions = PokerSession
      .joins(group: :memberships)
      .where(memberships: { user_id: current_user.id })
      .includes(:group, :session_results)
      .order(played_on: :desc)
      .limit(10)
  end
end
