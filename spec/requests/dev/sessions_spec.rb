require "rails_helper"

RSpec.describe "Dev::Sessions" do
  describe "POST /dev/session" do
    it "signs in as a developer user" do
      user = create(:user, provider: "developer")

      post dev_session_path, params: { user_id: user.id }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "refuses a user who signed up with Google" do
      user = create(:user)

      post dev_session_path, params: { user_id: user.id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
