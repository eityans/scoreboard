class PlayersController < ApplicationController
  before_action :set_group
  before_action :authorize_member!

  def index
    @players = @group.players.order(:display_name)
  end

  def new
    @player = @group.players.build
  end

  def create
    @player = @group.players.build(player_params)

    if @player.save
      redirect_to group_players_path(@group), notice: "「#{@player.display_name}」を追加しました"
    else
      render :new, status: :unprocessable_entity
    end
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
