module ApplicationHelper
  def format_amount(amount)
    return nil if amount.nil?

    display = amount == amount.to_i ? amount.to_i : amount
    number_with_delimiter(display)
  end

  def amount_input_value(amount)
    return nil if amount.nil?

    amount == amount.to_i ? amount.to_i.to_s : amount.to_s
  end

  def amount_unit_label(group)
    group.amount_unit_bb? ? "BB" : "点"
  end
end
