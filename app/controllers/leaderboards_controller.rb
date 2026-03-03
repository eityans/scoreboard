class LeaderboardsController < ApplicationController
  before_action :set_group
  before_action :authorize_member!

  def show
    resolve_quarter
    build_chart_data
    build_rankings
  end

  private

  def resolve_quarter
    all_sessions = @group.poker_sessions.order(:played_on)
    @quarters = all_sessions.pluck(:played_on).map { |d| quarter_key(d) }.uniq

    @quarter = params[:quarter].presence
    @quarter = @quarters.last if @quarter.nil?
    @quarter = nil if @quarter == "all"

    @date_range = quarter_date_range(@quarter) if @quarter
  end

  def build_rankings
    scope = @group.players.active.left_joins(:session_results)

    if @date_range
      scope = scope
        .joins("INNER JOIN poker_sessions ON poker_sessions.id = session_results.poker_session_id")
        .where(poker_sessions: { played_on: @date_range })
    end

    @rankings = scope
      .select("players.*, COALESCE(SUM(session_results.amount), 0) AS total_amount, COUNT(session_results.id) AS session_count")
      .group("players.id")
      .having("COUNT(session_results.id) > 0")
      .order("total_amount DESC")
  end

  def build_chart_data
    @min_sessions = [ params.fetch(:min_sessions, 3).to_i, 1 ].max
    sessions = @group.poker_sessions.includes(session_results: :player).order(:played_on)
    sessions = sessions.where(played_on: @date_range) if @date_range

    cumulative = Hash.new(0)
    participation_count = Hash.new(0)
    all_data = {}

    sessions.each_with_index do |session, i|
      session.session_results.each do |result|
        next if result.player.discarded?
        name = result.player.display_name
        all_data[name] ||= [ [ 0, 0 ] ]
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

  def quarter_key(date)
    q = ((date.month - 1) / 3) + 1
    "#{date.year}Q#{q}"
  end

  def quarter_date_range(key)
    return nil unless key&.match?(/\A\d{4}Q[1-4]\z/)
    year = key[0..3].to_i
    q = key[5].to_i
    start_month = (q - 1) * 3 + 1
    Date.new(year, start_month, 1)..Date.new(year, start_month + 2, -1)
  end

  def set_group
    @group = Group.find(params[:group_id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end
end
