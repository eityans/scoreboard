class SessionEntriesController < ApplicationController
  RECORDABLE_KINDS = %w[join rebuy cash_out].freeze

  before_action :set_group
  before_action :authorize_member!
  before_action :set_poker_session
  before_action :set_session_entry, only: [ :edit, :update, :destroy ]
  before_action :set_players, only: [ :new, :create, :edit, :update ]

  def new
    kind = params[:kind].presence_in(RECORDABLE_KINDS) || "join"
    @session_entry = @poker_session.session_entries.build(kind: kind, amount: default_amount(kind))
  end

  def create
    @session_entry = @poker_session.session_entries.build(session_entry_params)
    @session_entry.recorded_by = current_user

    if @session_entry.save
      redirect_to group_poker_session_path(@group, @poker_session), notice: "記録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @session_entry.update(session_entry_params)
      redirect_to group_poker_session_path(@group, @poker_session), notice: "記録を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @session_entry.destroy!
    redirect_to group_poker_session_path(@group, @poker_session), notice: "記録を削除しました"
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end

  def set_poker_session
    @poker_session = @group.poker_sessions.find(params[:poker_session_id])
  end

  def set_session_entry
    @session_entry = @poker_session.session_entries.find(params[:id])
  end

  def set_players
    @players = @group.players.active.order(:display_name)
  end

  def default_amount(kind)
    return unless kind.in?(%w[join rebuy])

    @poker_session.session_entries.where(kind: "join").order(:created_at, :id).last&.amount
  end

  def session_entry_params
    params.require(:session_entry).permit(:kind, :player_id, :amount)
  end
end
