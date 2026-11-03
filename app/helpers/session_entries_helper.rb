module SessionEntriesHelper
  KIND_LABELS = { "join" => "参加", "rebuy" => "リバイ", "cash_out" => "退出", "adjustment" => "調整" }.freeze

  def session_entry_kind_label(kind)
    KIND_LABELS.fetch(kind)
  end

  def session_entry_kind_options(entry)
    kinds = entry.adjustment? ? KIND_LABELS.keys : SessionEntriesController::RECORDABLE_KINDS
    kinds.map { |kind| [ session_entry_kind_label(kind), kind ] }
  end

  def session_entry_time(entry)
    entry.created_at.in_time_zone("Asia/Tokyo").strftime("%H:%M")
  end
end
