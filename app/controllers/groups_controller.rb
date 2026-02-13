class GroupsController < ApplicationController
  before_action :set_group, only: :show
  before_action :authorize_member!, only: :show

  def index
    @groups = current_user.groups
  end

  def show
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)
    @group.created_by = current_user

    if @group.save
      @group.memberships.create!(user: current_user, role: "owner")
      redirect_to @group, notice: "グループを作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end

  def group_params
    params.require(:group).permit(:name)
  end
end
