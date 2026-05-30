require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#format_amount" do
    it "returns nil for nil" do
      expect(helper.format_amount(nil)).to be_nil
    end

    it "drops trailing .0 for whole values" do
      expect(helper.format_amount(BigDecimal("1234.0"))).to eq("1,234")
    end

    it "keeps decimal part when non-zero" do
      expect(helper.format_amount(BigDecimal("100.5"))).to eq("100.5")
    end

    it "handles negative whole values" do
      expect(helper.format_amount(BigDecimal("-500.0"))).to eq("-500")
    end
  end

  describe "#amount_input_value" do
    it "returns nil for nil" do
      expect(helper.amount_input_value(nil)).to be_nil
    end

    it "returns integer string for whole values" do
      expect(helper.amount_input_value(BigDecimal("100.0"))).to eq("100")
    end

    it "returns decimal string for fractional values" do
      expect(helper.amount_input_value(BigDecimal("100.5"))).to eq("100.5")
    end
  end

  describe "#amount_unit_label" do
    it "returns '点' for a group with point unit" do
      group = build(:group, amount_unit: "point")
      expect(helper.amount_unit_label(group)).to eq("点")
    end

    it "returns 'BB' for a group with bb unit" do
      group = build(:group, amount_unit: "bb")
      expect(helper.amount_unit_label(group)).to eq("BB")
    end
  end
end
