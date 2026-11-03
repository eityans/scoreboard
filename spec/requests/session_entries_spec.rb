require "rails_helper"

RSpec.describe "SessionEntries" do
  let(:user) { create(:user) }
  let(:group) { create(:group, created_by: user) }
  let(:player) { create(:player, group: group) }
  let(:poker_session) { create(:poker_session, :live, group: group, created_by: user) }

  before do
    create(:membership, user: user, group: group, role: "owner")
    sign_in user
  end

  describe "GET new" do
    it "prefills the amount of the previous join" do
      create(:session_entry, poker_session: poker_session, player: player, kind: "join", amount: 500)

      get new_group_poker_session_session_entry_path(group, poker_session, kind: "join")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="500"')
    end
  end

  describe "POST create" do
    it "records an entry by the current user" do
      expect {
        post group_poker_session_session_entries_path(group, poker_session),
             params: { session_entry: { kind: "rebuy", player_id: player.id, amount: 300 } }
      }.to change(SessionEntry, :count).by(1)

      expect(SessionEntry.last).to have_attributes(kind: "rebuy", recorded_by: user, amount: 300)
      expect(response).to redirect_to(group_poker_session_path(group, poker_session))
    end

    it "re-renders the form for an invalid entry" do
      post group_poker_session_session_entries_path(group, poker_session),
           params: { session_entry: { kind: "rebuy", player_id: player.id, amount: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH update and DELETE destroy" do
    let!(:entry) { create(:session_entry, poker_session: poker_session, player: player, kind: "join", amount: 300) }

    it "changes the amount" do
      patch group_poker_session_session_entry_path(group, poker_session, entry),
            params: { session_entry: { amount: 400 } }

      expect(entry.reload.amount).to eq(400)
    end

    it "removes the entry" do
      expect {
        delete group_poker_session_session_entry_path(group, poker_session, entry)
      }.to change(SessionEntry, :count).by(-1)
    end
  end

  context "when user is not a member" do
    let(:other_session) { create(:poker_session, :live) }

    it "does not record an entry" do
      expect {
        post group_poker_session_session_entries_path(other_session.group, other_session),
             params: { session_entry: { kind: "join", player_id: create(:player, group: other_session.group).id, amount: 300 } }
      }.not_to change(SessionEntry, :count)

      expect(response).to redirect_to(groups_path)
    end
  end
end
