# グループごとのリーダーボードデフォルト設定

## 概要

グループごとにリーダーボードのデフォルトフィルタ（期間 / 最低参加回数）を設定できるようにする。グループの性質（クォーター単位で集計するグループ、全期間で1回以上の参加者を見せたいグループ）に応じて、初回アクセス時の表示を最適化する。

## 背景

現状、リーダーボード (`LeaderboardsController#show`) は URL パラメータが無指定の場合、以下の固定挙動になる:

- 期間 (`quarter`): 最新クォーター
- 最低参加回数 (`min_sessions`): `3`

これだと「全期間で1回でも参加した人を表示したい」というグループには合わない。グループごとに変更可能にする。

## 要件

- グループのメンバー全員が設定を編集できる
- 設定項目はリーダーボードのデフォルト期間と最低参加回数の2つ
- URL パラメータ指定があればそちらが優先される（既存のフィルタ操作は壊さない）

## データモデル

`groups` テーブルに2カラムを追加する:

```ruby
add_column :groups, :default_leaderboard_period, :string, null: false, default: "latest"
add_column :groups, :default_leaderboard_min_sessions, :integer, null: false, default: 3
```

`Group` モデル:

```ruby
enum :default_leaderboard_period, { latest: "latest", all: "all" }, prefix: :default_period
validates :default_leaderboard_min_sessions,
          numericality: { only_integer: true, greater_than_or_equal_to: 1 }
```

### `latest` のセマンティクス

`latest` は動的解決。保存時点での具体的クォーター (例: `2025Q4`) を固定するのではなく、リーダーボード閲覧時点での最新クォーターを毎回計算する。特定の過去クォーターをデフォルトに固定する用途は今回スコープ外。

## UI と画面遷移

### 追加するアクション

`GroupsController` に `edit` / `update` を追加する。権限は既存の `authorize_member!` を流用し、メンバー全員が編集可能とする。

### 画面遷移

1. グループ詳細 (`groups/show.html.erb`) に「設定」リンクを追加
2. クリックで `groups/edit.html.erb` (新規作成) に遷移
3. フォーム項目:
   - グループ名 (既存項目)
   - リーダーボードのデフォルト期間: ラジオ or セレクト（「最新クォーター」/「全期間」）
   - リーダーボードのデフォルト最低参加回数: `number_field` (min: 1)
4. 保存後はグループ詳細へ redirect、flash notice 表示

`group_params` の permit に `:default_leaderboard_period`, `:default_leaderboard_min_sessions` を追加する。

## リーダーボードのデフォルト解決

`LeaderboardsController` を以下のように変更する:

```ruby
def resolve_quarter
  all_sessions = @group.poker_sessions.order(:played_on)
  @quarters = all_sessions.pluck(:played_on).map { |d| quarter_key(d) }.uniq

  if params[:quarter].present?
    @quarter = params[:quarter] == "all" ? nil : params[:quarter]
  else
    @quarter = @group.default_period_all? ? nil : @quarters.last
  end

  @date_range = quarter_date_range(@quarter) if @quarter
end

def build_chart_data
  @min_sessions = [
    params.fetch(:min_sessions, @group.default_leaderboard_min_sessions).to_i,
    1
  ].max
  # ...以下は現状通り
end
```

優先順位は **URL パラメータ > グループのデフォルト > システムのフォールバック**。リーダーボード画面のフィルタ form 自体は変更しない。

## テスト

- `spec/models/group_spec.rb`: enum / validation
- `spec/requests/groups_spec.rb`: edit / update のリクエストスペック (権限含む)
- `spec/requests/leaderboards_spec.rb`: グループのデフォルト設定が無指定時に効くこと、params 指定があれば優先されること

## スコープ外 (YAGNI)

- 設定リセット機能
- 設定変更履歴
- owner / member ロール別の権限差
- リーダーボード画面の「これをデフォルトに」ボタン
- 特定クォーター固定をデフォルトに保存する機能

## 運用

- ブランチ: `feat/group-leaderboard-defaults`
- マージは PR ベース (memory 記録済みの運用ルールに従う)
