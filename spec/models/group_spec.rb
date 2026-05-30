require "rails_helper"

RSpec.describe Group, type: :model do
  describe "default leaderboard settings" do
    it "defaults default_leaderboard_period to 'latest'" do
      group = Group.new
      expect(group.default_leaderboard_period).to eq("latest")
    end

    it "defaults default_leaderboard_min_sessions to 3" do
      group = Group.new
      expect(group.default_leaderboard_min_sessions).to eq(3)
    end

    it "exposes default_period_latest? predicate" do
      group = Group.new(default_leaderboard_period: "latest")
      expect(group.default_period_latest?).to be true
    end

    it "exposes default_period_all? predicate" do
      group = Group.new(default_leaderboard_period: "all")
      expect(group.default_period_all?).to be true
    end

    it "rejects an unknown period value" do
      expect {
        Group.new(default_leaderboard_period: "weekly")
      }.to raise_error(ArgumentError)
    end

    it "is invalid when min_sessions is less than 1" do
      group = build(:group, default_leaderboard_min_sessions: 0)
      expect(group).to be_invalid
      expect(group.errors[:default_leaderboard_min_sessions]).to be_present
    end

    it "is invalid when min_sessions is not an integer" do
      group = build(:group, default_leaderboard_min_sessions: 1.5)
      expect(group).to be_invalid
    end

    it "is valid with allowed defaults" do
      group = build(:group, default_leaderboard_period: "all", default_leaderboard_min_sessions: 5)
      expect(group).to be_valid
    end
  end

  describe "amount unit" do
    it "defaults to 'point'" do
      group = Group.new
      expect(group.amount_unit).to eq("point")
    end

    it "exposes amount_unit_point? predicate" do
      group = Group.new(amount_unit: "point")
      expect(group.amount_unit_point?).to be true
    end

    it "exposes amount_unit_bb? predicate" do
      group = Group.new(amount_unit: "bb")
      expect(group.amount_unit_bb?).to be true
    end

    it "rejects an unknown unit value" do
      expect {
        Group.new(amount_unit: "yen")
      }.to raise_error(ArgumentError)
    end

    it "is valid with bb unit" do
      group = build(:group, amount_unit: "bb")
      expect(group).to be_valid
    end
  end
end
