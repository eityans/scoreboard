class PokerSessionsController < ApplicationController
  before_action :set_group
  before_action :authorize_member!
  before_action :set_poker_session, only: [ :show, :edit, :update, :destroy ]

  def index
    @poker_sessions = @group.poker_sessions.order(played_on: :desc)
  end

  def show
    @session_results = @poker_session.session_results.includes(:player).order("amount DESC")
  end

  def new
    @poker_session = @group.poker_sessions.build(played_on: Date.current)
    @players = @group.players.active.order(:display_name)
  end

  def create
    @poker_session = @group.poker_sessions.build(poker_session_params)
    @poker_session.created_by = current_user

    if @poker_session.save
      redirect_to group_poker_session_path(@group, @poker_session), notice: "セッションを記録しました"
    else
      @players = @group.players.active.order(:display_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @players = @group.players.active.order(:display_name)
  end

  def update
    if @poker_session.update(poker_session_params)
      redirect_to group_poker_session_path(@group, @poker_session), notice: "セッションを更新しました"
    else
      @players = @group.players.active.order(:display_name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @poker_session.destroy!
    redirect_to group_poker_sessions_path(@group), notice: "セッションを削除しました"
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def set_poker_session
    @poker_session = @group.poker_sessions.find(params[:id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end

  def poker_session_params
    params.require(:poker_session).permit(
      :played_on, :note,
      session_results_attributes: [ :id, :player_id, :amount, :_destroy ]
    )
  end
end
