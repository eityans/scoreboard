require "rails_helper"

RSpec.describe "Groups" do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /groups" do
    it "returns a successful response" do
      get groups_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /groups/:id" do
    context "when user is a member" do
      let(:group) { create(:group, created_by: user) }

      before { create(:membership, user: user, group: group, role: "owner") }

      it "returns a successful response" do
        get group_path(group)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not a member" do
      let(:group) { create(:group) }

      it "redirects to groups index" do
        get group_path(group)
        expect(response).to redirect_to(groups_path)
      end
    end
  end

  describe "GET /groups/new" do
    it "returns a successful response" do
      get new_group_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /groups" do
    context "with valid params" do
      it "creates a group and membership" do
        expect {
          post groups_path, params: { group: { name: "テストグループ" } }
        }.to change(Group, :count).by(1)
          .and change(Membership, :count).by(1)
      end

      it "redirects to the group" do
        post groups_path, params: { group: { name: "テストグループ" } }
        expect(response).to redirect_to(group_path(Group.last))
      end

      it "assigns the current user as owner" do
        post groups_path, params: { group: { name: "テストグループ" } }
        expect(Membership.last).to have_attributes(user: user, role: "owner")
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity" do
        post groups_path, params: { group: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /groups/:id/edit" do
    context "when user is a member" do
      let(:group) { create(:group, created_by: user) }

      before { create(:membership, user: user, group: group, role: "owner") }

      it "returns a successful response" do
        get edit_group_path(group)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not a member" do
      let(:group) { create(:group) }

      it "redirects to groups index" do
        get edit_group_path(group)
        expect(response).to redirect_to(groups_path)
      end
    end
  end

  describe "PATCH /groups/:id" do
    let(:group) { create(:group, created_by: user) }

    before { create(:membership, user: user, group: group, role: "owner") }

    context "with valid params" do
      it "updates leaderboard defaults" do
        patch group_path(group), params: {
          group: {
            default_leaderboard_period: "all",
            default_leaderboard_min_sessions: 1
          }
        }
        group.reload
        expect(group.default_leaderboard_period).to eq("all")
        expect(group.default_leaderboard_min_sessions).to eq(1)
      end

      it "redirects to the group" do
        patch group_path(group), params: { group: { name: "renamed" } }
        expect(response).to redirect_to(group_path(group))
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity for an empty name" do
        patch group_path(group), params: { group: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns unprocessable entity for an invalid min_sessions" do
        patch group_path(group), params: { group: { default_leaderboard_min_sessions: 0 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user is not a member" do
      let(:other_group) { create(:group) }

      it "redirects to groups index" do
        patch group_path(other_group), params: { group: { name: "hack" } }
        expect(response).to redirect_to(groups_path)
      end
    end
  end
end
