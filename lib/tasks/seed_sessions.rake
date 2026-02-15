namespace :seed do
  desc "Import poker session data from CSV (usage: GROUP_ID=1 USER_ID=1 rake seed:sessions)"
  task sessions: :environment do
    group_id = ENV.fetch("GROUP_ID") { raise "GROUP_ID を設定してください (例: GROUP_ID=1)" }
    user_id = ENV.fetch("USER_ID") { raise "USER_ID を設定してください (例: USER_ID=1)" }

    group = Group.find(group_id)
    user = User.find(user_id)

    player_names = %w[
      itochan kishida eityans para spicycoffee kick ame ataru miyan sorah
      kj dais yumoty bonami aito zakio uno sano shimizu tsutou
      taji matsuzaki shanonim nakayoshi
    ]

    sessions = {
      "2025-08-08" => { "itochan" => 874, "kishida" => 901, "eityans" => 16, "para" => -600, "spicycoffee" => -291, "kick" => -300 },
      "2025-08-15" => { "itochan" => 666, "eityans" => 444, "spicycoffee" => 60, "ame" => 795, "ataru" => -900, "miyan" => 889, "sorah" => -150, "kj" => -300 },
      "2025-08-29" => { "itochan" => 576, "eityans" => -108, "spicycoffee" => 390, "kick" => -26, "ataru" => 1220, "miyan" => -562, "kj" => -300, "dais" => 5 },
      "2025-09-12" => { "itochan" => 159, "kishida" => 169, "eityans" => -292, "spicycoffee" => 179, "kick" => 162, "dais" => 177, "yumoty" => -146 },
      "2025-10-03" => { "itochan" => -262, "eityans" => 137, "para" => 19, "spicycoffee" => 824, "kick" => 26, "bonami" => -67, "aito" => -258, "zakio" => 18, "uno" => -600, "sano" => 703 },
      "2025-10-07" => { "itochan" => -174, "eityans" => 153, "spicycoffee" => 220, "kick" => -600, "sano" => 401 },
      "2025-10-10" => { "itochan" => 1192, "eityans" => 110, "para" => -664, "spicycoffee" => 475, "kick" => 11, "dais" => -300, "tsutou" => -824 },
      "2025-10-17" => { "itochan" => -300, "eityans" => 257, "spicycoffee" => 204, "kick" => -161 },
      "2025-10-22" => { "itochan" => 131, "eityans" => -258, "spicycoffee" => 336, "ataru" => -48, "miyan" => 267, "shimizu" => -658 },
      "2025-10-24" => { "itochan" => -359, "kishida" => 412, "eityans" => -517, "para" => 487, "kick" => 388, "miyan" => 113, "dais" => 1276, "zakio" => -900, "tsutou" => -600 },
      "2025-11-07" => { "kishida" => -143, "eityans" => 473, "para" => -223, "spicycoffee" => 767, "kick" => 325, "ataru" => -600, "kj" => 2000, "taji" => 68, "zakio" => 230, "sano" => 1099 },
      "2025-11-21" => { "eityans" => 753, "kick" => -160, "miyan" => -223, "dais" => 208 },
      "2025-12-05" => { "eityans" => 524, "para" => 381, "kick" => -345, "miyan" => -311, "zakio" => -227 },
      "2025-12-19" => { "kishida" => -900, "eityans" => 517, "spicycoffee" => 448, "kick" => 337, "miyan" => 936, "dais" => 664 },
      "2025-12-26" => { "itochan" => -900, "eityans" => -316, "spicycoffee" => 280, "dais" => -600, "zakio" => 20 },
      "2026-01-09" => { "kishida" => 38, "eityans" => 305, "para" => 73, "spicycoffee" => 63, "kick" => -144, "zakio" => -76, "sano" => 374, "matsuzaki" => 518 },
      "2026-01-23" => { "eityans" => 498, "spicycoffee" => 233, "kick" => -51, "ame" => -245, "shanonim" => -300, "nakayoshi" => -225 },
      "2026-01-30" => { "eityans" => 322, "para" => -108, "spicycoffee" => 206, "kick" => -57, "shanonim" => -18, "nakayoshi" => -50 },
      "2026-02-06" => { "kishida" => -300, "spicycoffee" => -109, "kick" => 57, "zakio" => -500, "shanonim" => 1218 }
    }

    ActiveRecord::Base.transaction do
      players = {}
      player_names.each do |name|
        players[name] = group.players.find_or_create_by!(display_name: name)
      end
      puts "プレイヤー #{players.size}人 準備完了"

      sessions.each do |date_str, results|
        date = Date.parse(date_str)
        session = group.poker_sessions.find_or_initialize_by(played_on: date)
        if session.persisted?
          puts "  #{date_str} - スキップ (既存)"
          next
        end

        session.created_by = user
        session.save!

        results.each do |player_name, amount|
          session.session_results.create!(player: players[player_name], amount: amount)
        end
        puts "  #{date_str} - 作成 (#{results.size}人)"
      end
    end

    puts "=== 完了 ==="
  end
end
