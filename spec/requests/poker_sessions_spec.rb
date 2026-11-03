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

  describe "GET /groups/:group_id/poker_sessions with a live session" do
    it "labels the live session and counts players from entries" do
      live = create(:poker_session, :live, group: group, created_by: user)
      create(:session_entry, poker_session: live, player: player, kind: "join", amount: 300)

      get group_poker_sessions_path(group)

      expect(response.body).to include("ゲーム中", "1人参加")
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

    context "with decimal amount" do
      let(:params) do
        {
          poker_session: {
            played_on: "2025-01-15",
            session_results_attributes: {
              "0" => { player_id: player.id, amount: "123.5" }
            }
          }
        }
      end

      it "stores the amount with one decimal place" do
        post group_poker_sessions_path(group), params: params
        expect(SessionResult.last.amount).to eq(BigDecimal("123.5"))
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity" do
        post group_poker_sessions_path(group), params: { poker_session: { played_on: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /groups/:group_id/poker_sessions/start" do
    it "creates a live session for today" do
      post start_group_poker_sessions_path(group)

      session = PokerSession.last
      expect(session).to have_attributes(in_progress?: true, recorded_live?: true, played_on: Date.current, created_by: user)
      expect(response).to redirect_to(group_poker_session_path(group, session))
    end
  end

  describe "GET /groups/:group_id/poker_sessions/:id for a live session" do
    let(:poker_session) { create(:poker_session, :live, group: group, created_by: user) }

    it "shows the entry log" do
      create(:session_entry, poker_session: poker_session, player: player, recorded_by: user, kind: "join", amount: 300)

      get group_poker_session_path(group, poker_session)

      expect(response.body).to include(user.display_name, player.display_name)
    end
  end

  describe "PATCH /groups/:group_id/poker_sessions/:id/finish" do
    let(:poker_session) { create(:poker_session, :live, group: group, created_by: user) }

    before { create(:session_entry, poker_session: poker_session, player: player, kind: "join", amount: 300) }

    it "shows the finish button on the live screen" do
      get group_poker_session_path(group, poker_session)

      expect(response.body).to include("セッションを終了する")
    end

    it "completes the session once everyone has cashed out" do
      create(:session_entry, poker_session: poker_session, player: player, kind: "cash_out", amount: 400)

      patch finish_group_poker_session_path(group, poker_session)

      expect(poker_session.reload).to be_completed
      expect(poker_session.session_results.sole.amount).to eq(100)
      expect(response).to redirect_to(group_poker_session_path(group, poker_session))
    end

    it "keeps the session in progress while someone is seated" do
      patch finish_group_poker_session_path(group, poker_session)

      expect(poker_session.reload).to be_in_progress
      expect(flash[:alert]).to eq("全員の退出を記録してから終了してください")
    end

    it "does nothing for an already completed session" do
      create(:session_entry, poker_session: poker_session, player: player, kind: "cash_out", amount: 400)
      patch finish_group_poker_session_path(group, poker_session)

      expect {
        patch finish_group_poker_session_path(group, poker_session)
      }.not_to change(SessionResult, :count)
      expect(response).to redirect_to(group_poker_session_path(group, poker_session))
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

  describe "PATCH /groups/:group_id/poker_sessions/:id for a live session" do
    let(:poker_session) { create(:poker_session, :live, group: group, created_by: user) }

    before { create(:session_entry, poker_session: poker_session, player: player, kind: "join", amount: 300) }

    context "when completed" do
      before do
        create(:session_entry, poker_session: poker_session, player: player, kind: "cash_out", amount: 0)
        poker_session.finish!
      end

      it "shows only the amount fields of existing players" do
        get edit_group_poker_session_path(group, poker_session)

        expect(response.body).to include("results[#{player.id}]")
        expect(response.body).not_to include("参加者を追加")
      end

      it "records the difference as an adjustment" do
        patch group_poker_session_path(group, poker_session),
              params: { poker_session: { note: "直した" }, results: { player.id => "-200" } }

        expect(poker_session.session_entries.where(kind: "adjustment").sole).to have_attributes(amount: 100, recorded_by: user)
        expect(poker_session.session_results.sole.amount).to eq(-200)
        expect(poker_session.reload.note).to eq("直した")
      end

      it "adds no adjustment when the amount is unchanged" do
        expect {
          patch group_poker_session_path(group, poker_session),
                params: { poker_session: { note: "" }, results: { player.id => "-300" } }
        }.not_to change(SessionEntry, :count)
      end
    end

    context "when in progress" do
      it "updates the note but ignores results" do
        patch group_poker_session_path(group, poker_session),
              params: { poker_session: { note: "途中", session_results_attributes: { "0" => { player_id: player.id, amount: 500 } } },
                        results: { player.id => "500" } }

        expect(poker_session.reload.note).to eq("途中")
        expect(poker_session.session_results).to be_empty
        expect(poker_session.session_entries.count).to eq(1)
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
