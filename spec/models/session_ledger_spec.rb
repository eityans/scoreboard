require "rails_helper"

RSpec.describe SessionLedger do
  let(:poker_session) { create(:poker_session, :live) }
  let(:player) { create(:player, group: poker_session.group) }

  def record(kind, amount)
    create(:session_entry, poker_session: poker_session, player: player, kind: kind, amount: amount)
  end

  def row
    described_class.new(poker_session.session_entries.order(:created_at, :id).to_a).rows.sole
  end

  it "subtracts every buy-in from the cash-out" do
    record("join", 300)
    record("rebuy", 300)
    record("rebuy", 300)
    record("cash_out", 300)

    expect(row).to have_attributes(balance: -600, buy_in_total: 900, rebuy_count: 2, seated: false, last_cash_out: 300)
  end

  it "treats a player who rejoined after cashing out as seated" do
    record("join", 300)
    record("cash_out", 500)
    record("join", 300)

    expect(row).to have_attributes(balance: -100, seated: true)
  end

  it "adds adjustments to the balance" do
    record("join", 300)
    record("cash_out", 300)
    record("adjustment", 50)

    expect(row.balance).to eq(50)
  end

  it "does not treat a player with only adjustments as seated" do
    record("adjustment", -20)

    expect(row).to have_attributes(balance: -20, seated: false)
  end

  describe "#balances, #any_seated? and #any_join?" do
    it "summarizes all players" do
      record("join", 300)
      ledger = described_class.new(poker_session.session_entries.to_a)

      expect(ledger.balances).to eq(player.id => -300)
      expect(ledger).to be_any_seated
      expect(ledger).to be_any_join
    end

    it "is empty without entries" do
      ledger = described_class.new([])

      expect(ledger.balances).to eq({})
      expect(ledger).not_to be_any_seated
      expect(ledger).not_to be_any_join
    end
  end
end
