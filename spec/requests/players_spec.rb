require "rails_helper"

RSpec.describe "Players" do
  let(:user) { create(:user) }
  let(:group) { create(:group, created_by: user) }

  before do
    create(:membership, user: user, group: group, role: "owner")
    sign_in user
  end

  describe "GET /groups/:group_id/players" do
    it "returns a successful response" do
      get group_players_path(group)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /groups/:group_id/players/new" do
    it "returns a successful response" do
      get new_group_player_path(group)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /groups/:group_id/players" do
    context "with valid params" do
      it "creates a player" do
        expect {
          post group_players_path(group), params: { player: { display_name: "太郎" } }
        }.to change(Player, :count).by(1)
      end

      it "redirects to players index" do
        post group_players_path(group), params: { player: { display_name: "太郎" } }
        expect(response).to redirect_to(group_players_path(group))
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity" do
        post group_players_path(group), params: { player: { display_name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  context "when user is not a member" do
    let(:other_group) { create(:group) }

    it "redirects to groups index" do
      get group_players_path(other_group)
      expect(response).to redirect_to(groups_path)
    end
  end
end
