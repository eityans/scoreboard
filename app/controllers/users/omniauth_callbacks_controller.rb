class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = User.from_omniauth(request.env["omniauth.auth"])

    if user.persisted?
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      redirect_to new_user_session_path, alert: user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "認証に失敗しました。もう一度お試しください。"
  end
end
