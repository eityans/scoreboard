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

    context "with quarterly filter" do
      let(:player_a) { create(:player, group: group, display_name: "Alice") }
      let(:player_b) { create(:player, group: group, display_name: "Bob") }

      before do
        q4_session = create(:poker_session, group: group, created_by: user, played_on: Date.new(2025, 10, 15))
        create(:session_result, poker_session: q4_session, player: player_a, amount: 500)
        create(:session_result, poker_session: q4_session, player: player_b, amount: -500)

        q1_session = create(:poker_session, group: group, created_by: user, played_on: Date.new(2026, 1, 20))
        create(:session_result, poker_session: q1_session, player: player_a, amount: -300)
        create(:session_result, poker_session: q1_session, player: player_b, amount: 300)
      end

      it "defaults to the latest quarter" do
        get group_leaderboard_path(group)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("2026Q1")
      end

      it "filters by specified quarter" do
        get group_leaderboard_path(group), params: { quarter: "2025Q4" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alice")
        expect(response.body).to include("500")
      end

      it "shows all periods when quarter is 'all'" do
        get group_leaderboard_path(group), params: { quarter: "all" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alice")
        expect(response.body).to include("Bob")
      end
    end

    context "with min_sessions filter" do
      it "filters players by minimum session count" do
        player = create(:player, group: group, display_name: "常連")
        3.times do |i|
          session = create(:poker_session, group: group, created_by: user, played_on: Date.current - i.days)
          create(:session_result, poker_session: session, player: player, amount: 100)
        end

        get group_leaderboard_path(group), params: { quarter: "all", min_sessions: 3 }
        expect(response).to have_http_status(:ok)
      end
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
