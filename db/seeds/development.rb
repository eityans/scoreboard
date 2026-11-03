developers = %w[alice bob carol].map do |name|
  User.find_or_create_by!(provider: User::DEVELOPER_PROVIDER, uid: name) do |user|
    user.email = "#{name}@example.com"
    user.display_name = name.capitalize
    user.password = Devise.friendly_token[0, 20]
  end
end

group = Group.find_or_create_by!(name: "開発用グループ") do |g|
  g.created_by = developers.first
end

developers.each_with_index do |user, i|
  Membership.find_or_create_by!(user: user, group: group) { |m| m.role = i.zero? ? "owner" : "member" }
end

players = developers.map { |user| Player.find_or_create_by!(group: group, display_name: user.display_name) { |p| p.user = user } }
players += %w[Dave Eve].map { |name| Player.find_or_create_by!(group: group, display_name: name) }

if group.poker_sessions.none?
  [
    [ Date.new(2026, 8, 2), [ 1200, -300, -500, -400, 0 ] ],
    [ Date.new(2026, 8, 23), [ -600, 900, 300, nil, -600 ] ],
    [ Date.new(2026, 9, 13), [ 200, -700, nil, 800, -300 ] ],
    [ Date.new(2026, 10, 4), [ -400, 100, 700, -400, nil ] ],
    [ Date.new(2026, 10, 25), [ 500, nil, -900, 100, 300 ] ]
  ].each do |played_on, amounts|
    session = group.poker_sessions.create!(played_on: played_on, created_by: developers.first)
    players.zip(amounts).each do |player, amount|
      session.session_results.create!(player: player, amount: amount) unless amount.nil?
    end
  end
end

if group.poker_sessions.in_progress.none?
  live = group.poker_sessions.create!(played_on: Date.current, created_by: developers.first, status: :in_progress, recorded_live: true)
  alice, bob, carol = players
  [
    [ alice, "join", 300 ], [ bob, "join", 300 ], [ carol, "join", 300 ],
    [ alice, "rebuy", 300 ], [ bob, "cash_out", 800 ]
  ].each do |player, kind, amount|
    live.session_entries.create!(player: player, kind: kind, amount: amount, recorded_by: developers.first)
  end
end
