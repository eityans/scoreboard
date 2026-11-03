class SessionLedger
  Row = Data.define(:player, :buy_in_total, :rebuy_count, :cash_out_total, :balance, :seated, :last_cash_out)

  def initialize(entries)
    @entries = entries
  end

  def rows
    @rows ||= @entries.group_by(&:player).map { |player, entries| build_row(player, entries) }
  end

  def balances
    rows.to_h { |row| [ row.player.id, row.balance ] }
  end

  def any_seated?
    rows.any?(&:seated)
  end

  def any_join?
    @entries.any?(&:join?)
  end

  private

  def build_row(player, entries)
    totals = Hash.new(0).merge(entries.group_by(&:kind).transform_values { |list| list.sum(&:amount) })
    buy_in_total = totals["join"] + totals["rebuy"]
    last_join = entries.rindex(&:join?)
    last_cash_out = entries.rindex(&:cash_out?)

    Row.new(
      player: player,
      buy_in_total: buy_in_total,
      rebuy_count: entries.count(&:rebuy?),
      cash_out_total: totals["cash_out"],
      balance: totals["cash_out"] - buy_in_total + totals["adjustment"],
      seated: !last_join.nil? && (last_cash_out.nil? || last_cash_out < last_join),
      last_cash_out: last_cash_out && entries[last_cash_out].amount
    )
  end
end
