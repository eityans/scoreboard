require "rails_helper"

RSpec.describe "Dashboard" do
  describe "GET /" do
    context "when not signed in" do
      it "redirects to sign in page" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "labels a live session" do
        group = create(:group, created_by: user)
        create(:membership, user: user, group: group, role: "owner")
        create(:poker_session, :live, group: group, created_by: user)

        get root_path

        expect(response.body).to include("ゲーム中")
      end

      it "returns a successful response" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
