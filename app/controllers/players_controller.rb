class PlayersController < ApplicationController
  before_action :set_group
  before_action :authorize_member!

  def index
    @players = @group.players.active.order(:display_name)
  end

  def new
    @player = @group.players.build
  end

  def create
    @player = @group.players.build(player_params)

    if @player.save
      respond_to do |format|
        format.html { redirect_to group_players_path(@group), notice: "「#{@player.display_name}」を追加しました" }
        format.json { render json: { id: @player.id, display_name: @player.display_name }, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @player.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @player = @group.players.find(params[:id])
    @player.discard
    redirect_to group_players_path(@group), notice: "「#{@player.display_name}」を削除しました"
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end

  def player_params
    params.require(:player).permit(:display_name)
  end
end
