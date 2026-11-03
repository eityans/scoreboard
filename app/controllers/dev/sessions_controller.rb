module Dev
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user!
    before_action { head :not_found unless Rails.env.local? }

    def create
      user = User.find_by(id: params[:user_id], provider: User::DEVELOPER_PROVIDER)
      return head :not_found unless user

      sign_in user
      redirect_to root_path
    end
  end
end
