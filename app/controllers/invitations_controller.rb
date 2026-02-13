class InvitationsController < ApplicationController
  def show
    group = Group.find_by!(invitation_token: params[:token])

    if current_user.groups.include?(group)
      redirect_to group, notice: "すでにこのグループに参加しています"
    else
      group.memberships.create!(user: current_user, role: "member")
      redirect_to group, notice: "「#{group.name}」に参加しました"
    end
  end
end
