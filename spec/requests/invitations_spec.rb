require "rails_helper"

RSpec.describe "Invitations" do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before { sign_in user }

  describe "GET /invitations/:token" do
    context "when user is not yet a member" do
      it "creates a membership" do
        expect {
          get invitation_path(token: group.invitation_token)
        }.to change(Membership, :count).by(1)
      end

      it "redirects to the group" do
        get invitation_path(token: group.invitation_token)
        expect(response).to redirect_to(group_path(group))
      end

      it "assigns the member role" do
        get invitation_path(token: group.invitation_token)
        expect(Membership.last).to have_attributes(user: user, group: group, role: "member")
      end
    end

    context "when user is already a member" do
      before { create(:membership, user: user, group: group) }

      it "does not create a duplicate membership" do
        expect {
          get invitation_path(token: group.invitation_token)
        }.not_to change(Membership, :count)
      end

      it "redirects to the group" do
        get invitation_path(token: group.invitation_token)
        expect(response).to redirect_to(group_path(group))
      end
    end

    context "with invalid token" do
      it "returns not found" do
        get invitation_path(token: "invalid_token")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
