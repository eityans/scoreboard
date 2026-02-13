require "rails_helper"

RSpec.describe "PokerSessions" do
  let(:user) { create(:user) }
  let(:group) { create(:group, created_by: user) }
  let(:player) { create(:player, group: group) }

  before do
    create(:membership, user: user, group: group, role: "owner")
    sign_in user
  end

  describe "GET /groups/:group_id/poker_sessions" do
    it "returns a successful response" do
      get group_poker_sessions_path(group)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /groups/:group_id/poker_sessions/:id" do
    let(:poker_session) { create(:poker_session, group: group, created_by: user) }

    it "returns a successful response" do
      get group_poker_session_path(group, poker_session)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /groups/:group_id/poker_sessions/new" do
    it "returns a successful response" do
      get new_group_poker_session_path(group)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /groups/:group_id/poker_sessions" do
    context "with valid params" do
      let(:params) do
        {
          poker_session: {
            played_on: "2025-01-15",
            note: "テストセッション",
            session_results_attributes: {
              "0" => { player_id: player.id, amount: 500 }
            }
          }
        }
      end

      it "creates a poker session with results" do
        expect {
          post group_poker_sessions_path(group), params: params
        }.to change(PokerSession, :count).by(1)
          .and change(SessionResult, :count).by(1)
      end

      it "redirects to the poker session" do
        post group_poker_sessions_path(group), params: params
        expect(response).to redirect_to(group_poker_session_path(group, PokerSession.last))
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity" do
        post group_poker_sessions_path(group), params: { poker_session: { played_on: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /groups/:group_id/poker_sessions/:id/edit" do
    let(:poker_session) { create(:poker_session, group: group, created_by: user) }

    it "returns a successful response" do
      get edit_group_poker_session_path(group, poker_session)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /groups/:group_id/poker_sessions/:id" do
    let(:poker_session) { create(:poker_session, group: group, created_by: user) }

    context "with valid params" do
      it "updates the poker session" do
        patch group_poker_session_path(group, poker_session),
              params: { poker_session: { note: "更新メモ" } }
        expect(poker_session.reload.note).to eq("更新メモ")
      end

      it "redirects to the poker session" do
        patch group_poker_session_path(group, poker_session),
              params: { poker_session: { note: "更新メモ" } }
        expect(response).to redirect_to(group_poker_session_path(group, poker_session))
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity" do
        patch group_poker_session_path(group, poker_session),
              params: { poker_session: { played_on: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /groups/:group_id/poker_sessions/:id" do
    let!(:poker_session) { create(:poker_session, group: group, created_by: user) }

    it "destroys the poker session" do
      expect {
        delete group_poker_session_path(group, poker_session)
      }.to change(PokerSession, :count).by(-1)
    end

    it "redirects to poker sessions index" do
      delete group_poker_session_path(group, poker_session)
      expect(response).to redirect_to(group_poker_sessions_path(group))
    end
  end

  context "when user is not a member" do
    let(:other_group) { create(:group) }

    it "redirects to groups index" do
      get group_poker_sessions_path(other_group)
      expect(response).to redirect_to(groups_path)
    end
  end
end
