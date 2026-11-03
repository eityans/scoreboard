require "rails_helper"

RSpec.describe SessionEntry, type: :model do
  it { is_expected.to belong_to(:poker_session) }
  it { is_expected.to belong_to(:player) }
  it { is_expected.to belong_to(:recorded_by).class_name("User") }

  describe "amount" do
    it "rejects a negative rebuy" do
      expect(build(:session_entry, kind: "rebuy", amount: -1)).to be_invalid
    end

    it "accepts a negative adjustment" do
      expect(build(:session_entry, kind: "adjustment", amount: -1)).to be_valid
    end
  end

  describe "player" do
    it "rejects a player from another group" do
      entry = build(:session_entry, player: create(:player))
      expect(entry).to be_invalid
    end
  end
end
