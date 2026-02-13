require "rails_helper"

RSpec.describe "Leaderboards" do
  let(:user) { create(:user) }
  let(:group) { create(:group, created_by: user) }

  before do
    create(:membership, user: user, group: group, role: "owner")
    sign_in user
  end

  describe "GET /groups/:group_id/leaderboard" do
    it "returns a successful response" do
      get group_leaderboard_path(group)
      expect(response).to have_http_status(:ok)
    end

    it "returns a successful response with players and results" do
      player = create(:player, group: group, display_name: "太郎")
      session = create(:poker_session, group: group, created_by: user)
      create(:session_result, poker_session: session, player: player, amount: 1000)

      get group_leaderboard_path(group)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("太郎")
      expect(response.body).to include("1,000")
    end
  end

  context "when user is not a member" do
    let(:other_group) { create(:group) }

    it "redirects to groups index" do
      get group_leaderboard_path(other_group)
      expect(response).to redirect_to(groups_path)
    end
  end
end
