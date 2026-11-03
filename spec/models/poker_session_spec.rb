require "rails_helper"

RSpec.describe PokerSession, type: :model do
  let(:poker_session) { create(:poker_session, :live) }
  let(:alice) { create(:player, group: poker_session.group) }
  let(:bob) { create(:player, group: poker_session.group) }

  def record(player, kind, amount)
    create(:session_entry, poker_session: poker_session, player: player, kind: kind, amount: amount)
  end

  def results
    poker_session.session_results.reload.to_h { |result| [ result.player_id, result.amount ] }
  end

  describe "#finish!" do
    it "writes balances computed from entries when everyone has cashed out" do
      record(alice, "join", 300)
      record(alice, "rebuy", 300)
      record(alice, "cash_out", 100)
      record(bob, "join", 300)
      record(bob, "cash_out", 800)

      expect(poker_session.finish!).to be(true)
      expect(poker_session.reload).to be_completed
      expect(results).to eq(alice.id => -500, bob.id => 500)
    end

    it "refuses to finish while someone is seated" do
      record(alice, "join", 300)

      expect(poker_session.finish!).to be(false)
      expect(poker_session.reload).to be_in_progress
      expect(results).to be_empty
    end

    it "succeeds for a stale instance whose session another member already finished" do
      record(alice, "join", 300)
      record(alice, "cash_out", 300)
      stale = described_class.find(poker_session.id)
      poker_session.finish!

      expect(stale.finish!).to be(true)
    end

    it "refuses to finish without any join" do
      expect(poker_session.finish!).to be(false)
    end
  end

  context "when a finished live session is changed" do
    let!(:cash_out) do
      record(alice, "join", 300)
      record(alice, "cash_out", 500)
    end

    before { poker_session.finish! }

    it "follows an edited cash-out" do
      cash_out.update!(amount: 700)

      expect(results).to eq(alice.id => 400)
    end

    it "reopens the session when a cash-out is removed" do
      cash_out.destroy!

      expect(poker_session.reload).to be_in_progress
      expect(results).to be_empty
    end

    it "drops the result of a player whose entries are all removed" do
      record(bob, "adjustment", 10)
      poker_session.session_entries.where(player: bob).destroy_all

      expect(results).to eq(alice.id => 200)
    end

    it "recomputes results even when the entry holds a stale session" do
      stale_entry = SessionEntry.find(cash_out.id)
      stale_entry.poker_session.update_column(:status, "in_progress")
      stale_entry.poker_session.status = "in_progress"
      described_class.find(poker_session.id).update_column(:status, "completed")

      stale_entry.update!(amount: 900)

      expect(results).to eq(alice.id => 600)
    end

    it "can be destroyed with its entries and results" do
      expect { poker_session.destroy! }.to change(SessionResult, :count).by(-1)
        .and change(SessionEntry, :count).by(-2)
    end
  end

  describe "#sync_results!" do
    it "leaves results of a session entered after the game untouched" do
      session = create(:poker_session)
      result = create(:session_result, poker_session: session, player: create(:player, group: session.group), amount: 100)

      session.sync_results!

      expect(result.reload.amount).to eq(100)
    end
  end

  describe "#participant_count" do
    it "counts players in entries while in progress" do
      record(alice, "join", 300)
      record(alice, "rebuy", 300)
      record(bob, "join", 300)

      expect(poker_session.participant_count).to eq(2)
    end

    it "counts results once completed" do
      session = create(:poker_session)
      create(:session_result, poker_session: session, player: create(:player, group: session.group))

      expect(session.participant_count).to eq(1)
    end
  end
end
