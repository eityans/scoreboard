class LeaderboardsController < ApplicationController
  before_action :set_group
  before_action :authorize_member!

  def show
    @rankings = @group.players.active
      .left_joins(:session_results)
      .select("players.*, COALESCE(SUM(session_results.amount), 0) AS total_amount, COUNT(session_results.id) AS session_count")
      .group("players.id")
      .order("total_amount DESC")

    build_chart_data
  end

  private

  def build_chart_data
    @min_sessions = [ params.fetch(:min_sessions, 3).to_i, 1 ].max
    sessions = @group.poker_sessions.includes(session_results: :player).order(:played_on)

    cumulative = Hash.new(0)
    participation_count = Hash.new(0)
    all_data = {}

    sessions.each_with_index do |session, i|
      session.session_results.each do |result|
        next if result.player.discarded?
        name = result.player.display_name
        all_data[name] ||= [[0, 0]]
        cumulative[name] += result.amount
        participation_count[name] += 1
      end

      cumulative.each do |name, total|
        all_data[name] << [ i + 1, total ]
      end
    end

    filtered = all_data.select { |name, _| participation_count[name] >= @min_sessions }
    @chart_data = filtered.map { |name, data| { name: name, data: data } }

    all_values = filtered.values.flatten(1).map(&:last)
    if all_values.any?
      padding = [ (all_values.max - all_values.min) * 0.1, 100 ].max.ceil
      @chart_min = all_values.min - padding
      @chart_max = all_values.max + padding
    end
  end

  def set_group
    @group = Group.find(params[:group_id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end
end
