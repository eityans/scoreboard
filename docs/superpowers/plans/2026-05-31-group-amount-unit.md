# Group Amount Unit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** グループごとに収支の表示単位 (点 / BB) を選べるようにし、設定された単位が収支表示・入力欄プレースホルダ・チャート軸ラベルなど全箇所に反映されるようにする。

**Architecture:** `groups` テーブルに `amount_unit` カラム (enum: point/bb、デフォルト point) を追加。`ApplicationHelper#amount_unit_label(group)` で表示ラベルを解決し、既存の「点」リテラルが書かれていた view 群を helper 経由に書き換える。数値変換は行わない。

**Tech Stack:** Rails 8.1, RSpec, PostgreSQL, Tailwind CSS

**Spec:** `docs/superpowers/specs/2026-05-30-group-amount-unit-design.md`

**Branch:** `feat/group-amount-unit`（作業開始時点で既に切られている前提）

---

## File Map

**Create:**
- `db/migrate/20260531100100_add_amount_unit_to_groups.rb`

**Modify:**
- `db/schema.rb` (マイグレーション実行で自動更新)
- `app/models/group.rb`
- `app/helpers/application_helper.rb`
- `app/controllers/groups_controller.rb`
- `app/views/groups/edit.html.erb`
- `app/views/poker_sessions/show.html.erb`
- `app/views/poker_sessions/_form.html.erb`
- `app/views/poker_sessions/_session_result_fields.html.erb`
- `app/views/dashboard/show.html.erb`
- `app/views/leaderboards/show.html.erb`
- `spec/models/group_spec.rb`
- `spec/helpers/application_helper_spec.rb`
- `spec/requests/groups_spec.rb`

---

### Task 1: groups に amount_unit カラムを追加するマイグレーション

**Files:**
- Create: `db/migrate/20260531100100_add_amount_unit_to_groups.rb`
- Modify: `db/schema.rb` (auto)

- [ ] **Step 1: マイグレーションファイルを作成**

`db/migrate/20260531100100_add_amount_unit_to_groups.rb`:

```ruby
class AddAmountUnitToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :amount_unit, :string, null: false, default: "point"
  end
end
```

- [ ] **Step 2: マイグレーションを実行**

Run: `bin/rails db:migrate`
Expected: `add_column(:groups, :amount_unit, :string, ...)` が migrated と表示される。

- [ ] **Step 3: schema.rb の更新を確認**

Run: `grep -A 12 'create_table "scoreboard.groups"' db/schema.rb`
Expected: 出力に `t.string "amount_unit", default: "point", null: false` を含む。

- [ ] **Step 4: テスト DB にも反映**

Run: `bin/rails db:test:prepare`
Expected: 成功 (出力なし or 軽微なログのみ)。

- [ ] **Step 5: コミット**

```bash
git add db/migrate/20260531100100_add_amount_unit_to_groups.rb db/schema.rb
git commit -m "$(cat <<'EOF'
feat(group): add amount_unit column to groups

収支の表示単位 (point / bb) をグループごとに保存するカラムを追加。
デフォルトは "point" でこれまでの挙動を維持する。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Group モデルに enum を追加 (TDD)

**Files:**
- Modify: `app/models/group.rb`
- Modify: `spec/models/group_spec.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/models/group_spec.rb` の `describe "default leaderboard settings" do ... end` ブロックの **直後** (一番下の `end` の前) に以下を追加する:

```ruby
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
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/models/group_spec.rb -e "amount unit"`
Expected: `amount_unit_point?` / `amount_unit_bb?` が未定義のため `NoMethodError`、未知の値で `ArgumentError` が出ないため失敗で、複数失敗する。

- [ ] **Step 3: Group モデルに enum を追加**

`app/models/group.rb` の `enum :default_leaderboard_period, { latest: "latest", all: "all" }, prefix: :default_period` の **直後の行** に以下を追加する:

```ruby
  enum :amount_unit, { point: "point", bb: "bb" }, prefix: :amount_unit
```

- [ ] **Step 4: テスト通過を確認**

Run: `bundle exec rspec spec/models/group_spec.rb`
Expected: 13 examples, 0 failures (既存 8 + 新規 5)。

- [ ] **Step 5: コミット**

```bash
git add app/models/group.rb spec/models/group_spec.rb
git commit -m "$(cat <<'EOF'
feat(group): add amount_unit enum

amount_unit を point/bb の enum として宣言し、predicate メソッドを公開。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: ApplicationHelper#amount_unit_label を追加 (TDD)

**Files:**
- Modify: `app/helpers/application_helper.rb`
- Modify: `spec/helpers/application_helper_spec.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/helpers/application_helper_spec.rb` の最終行 `end` (RSpec.describe の閉じ) の **直前** に以下の describe を追加:

```ruby
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
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/helpers/application_helper_spec.rb -e "amount_unit_label"`
Expected: `NoMethodError: undefined method 'amount_unit_label'` で 2 failures。

- [ ] **Step 3: ヘルパーを実装**

`app/helpers/application_helper.rb` の `amount_input_value` メソッドの **直後** (最後の `end` の前) に以下を追加:

```ruby
  def amount_unit_label(group)
    group.amount_unit_bb? ? "BB" : "点"
  end
```

- [ ] **Step 4: テスト通過を確認**

Run: `bundle exec rspec spec/helpers/application_helper_spec.rb`
Expected: 9 examples, 0 failures (既存 7 + 新規 2)。

- [ ] **Step 5: コミット**

```bash
git add app/helpers/application_helper.rb spec/helpers/application_helper_spec.rb
git commit -m "$(cat <<'EOF'
feat(helper): add amount_unit_label helper

グループの amount_unit に応じて表示ラベル ("点" / "BB") を返すヘルパーを追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: GroupsController で amount_unit を permit + 編集 UI 追加 (TDD)

**Files:**
- Modify: `app/controllers/groups_controller.rb`
- Modify: `app/views/groups/edit.html.erb`
- Modify: `spec/requests/groups_spec.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/requests/groups_spec.rb` の `describe "PATCH /groups/:id"` ブロック内、`context "with valid params"` の中の `it "redirects to the group" do` の **後** (`end` の次) に以下を追加:

```ruby
      it "updates amount_unit" do
        patch group_path(group), params: { group: { amount_unit: "bb" } }
        expect(group.reload.amount_unit).to eq("bb")
      end
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/requests/groups_spec.rb -e "updates amount_unit"`
Expected: `expect(group.reload.amount_unit).to eq("bb")` が `eq "point"` で失敗 (strong parameters が permit していないため更新されない)。

- [ ] **Step 3: group_params に amount_unit を追加**

`app/controllers/groups_controller.rb` の `group_params` メソッドを以下に書き換える:

```ruby
  def group_params
    params.require(:group).permit(:name, :default_leaderboard_period, :default_leaderboard_min_sessions, :amount_unit)
  end
```

- [ ] **Step 4: edit.html.erb に「記録設定」fieldset を追加**

`app/views/groups/edit.html.erb` の `<fieldset class="border-t border-gray-100 pt-5">` で始まる「リーダーボードのデフォルト」fieldset の **直前** に以下を挿入:

```erb
    <fieldset class="border-t border-gray-100 pt-5">
      <legend class="text-sm font-semibold text-gray-700 mb-3">記録設定</legend>

      <div>
        <%= form.label :amount_unit, "収支の単位", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= form.select :amount_unit,
              [["点", "point"], ["BB", "bb"]],
              {},
              class: "w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition" %>
        <p class="text-xs text-gray-500 mt-1">表示単位のみ切り替わります。既存データの数値は変わりません。</p>
      </div>
    </fieldset>

```

- [ ] **Step 5: テスト通過を確認**

Run: `bundle exec rspec spec/requests/groups_spec.rb`
Expected: 16 examples, 0 failures (既存 15 + 新規 1)。

- [ ] **Step 6: コミット**

```bash
git add app/controllers/groups_controller.rb app/views/groups/edit.html.erb spec/requests/groups_spec.rb
git commit -m "$(cat <<'EOF'
feat(group): allow editing amount_unit from settings page

GroupsController#group_params に :amount_unit を permit し、設定画面に
「記録設定」fieldset を追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 各 view の「点」表記を amount_unit_label に置き換え

**Files:**
- Modify: `app/views/poker_sessions/show.html.erb`
- Modify: `app/views/poker_sessions/_form.html.erb`
- Modify: `app/views/poker_sessions/_session_result_fields.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Modify: `app/views/leaderboards/show.html.erb`

このタスクは UI 描画ラベルの差し替えで、TDD ではなく既存 spec を壊さないことを通過条件とする。

- [ ] **Step 1: poker_sessions/show.html.erb を更新**

`app/views/poker_sessions/show.html.erb` の以下の行:

```erb
            <%= result.amount >= 0 ? "+" : "" %><%= format_amount(result.amount) %> 点
```

を以下に置き換える:

```erb
            <%= result.amount >= 0 ? "+" : "" %><%= format_amount(result.amount) %> <%= amount_unit_label(@poker_session.group) %>
```

さらに同ファイル内の以下の行:

```erb
        <%= total >= 0 ? "+" : "" %><%= format_amount(total) %> 点
```

を以下に置き換える:

```erb
        <%= total >= 0 ? "+" : "" %><%= format_amount(total) %> <%= amount_unit_label(@poker_session.group) %>
```

- [ ] **Step 2: poker_sessions/_form.html.erb で partial に group を渡す**

`app/views/poker_sessions/_form.html.erb` 内の以下の **2 箇所** を書き換える。

1 つ目:

```erb
            <%= render "poker_sessions/session_result_fields", form: result_form, players: players %>
```

を:

```erb
            <%= render "poker_sessions/session_result_fields", form: result_form, players: players, group: @group %>
```

2 つ目 (template ブロック内):

```erb
          <%= render "poker_sessions/session_result_fields", form: result_form, players: players %>
```

を:

```erb
          <%= render "poker_sessions/session_result_fields", form: result_form, players: players, group: @group %>
```

- [ ] **Step 3: poker_sessions/_session_result_fields.html.erb の placeholder を helper 経由に**

`app/views/poker_sessions/_session_result_fields.html.erb` の以下の行:

```erb
    <%= form.number_field :amount, step: 0.1, value: amount_input_value(form.object.amount), placeholder: "収支(点)", class: "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-right focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition" %>
```

を以下に置き換える:

```erb
    <%= form.number_field :amount, step: 0.1, value: amount_input_value(form.object.amount), placeholder: "収支(#{amount_unit_label(group)})", class: "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm text-right focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition" %>
```

- [ ] **Step 4: dashboard/show.html.erb を更新**

`app/views/dashboard/show.html.erb` の以下の行:

```erb
                <span class="text-xs text-yellow-600 font-medium">収支合計: <%= total > 0 ? "+" : "" %><%= format_amount(total) %>点</span>
```

を以下に置き換える:

```erb
                <span class="text-xs text-yellow-600 font-medium">収支合計: <%= total > 0 ? "+" : "" %><%= format_amount(total) %><%= amount_unit_label(session.group) %></span>
```

- [ ] **Step 5: leaderboards/show.html.erb を更新**

`app/views/leaderboards/show.html.erb` のチャート呼び出し行:

```erb
        <%= line_chart @chart_data, xtitle: "セッション", ytitle: "累計 (点)", points: false, curve: false, legend: "bottom", min: @chart_min, max: @chart_max, height: "500px",
              library: { scales: { x: { ticks: { stepSize: 1 } } } } %>
```

を以下に置き換える:

```erb
        <%= line_chart @chart_data, xtitle: "セッション", ytitle: "累計 (#{amount_unit_label(@group)})", points: false, curve: false, legend: "bottom", min: @chart_min, max: @chart_max, height: "500px",
              library: { scales: { x: { ticks: { stepSize: 1 } } } } %>
```

さらに同ファイル内の以下の行:

```erb
                    <%= player.total_amount.positive? ? "+" : "" %><%= format_amount(player.total_amount) %>点
```

を以下に置き換える:

```erb
                    <%= player.total_amount.positive? ? "+" : "" %><%= format_amount(player.total_amount) %><%= amount_unit_label(@group) %>
```

- [ ] **Step 6: 全 spec を実行して回帰がないことを確認**

Run: `bundle exec rspec`
Expected: 全 spec 通過 (failures: 0)。

- [ ] **Step 7: lint**

Run: `bin/rubocop`
Expected: no offenses detected.

- [ ] **Step 8: コミット**

```bash
git add app/views/poker_sessions/show.html.erb app/views/poker_sessions/_form.html.erb app/views/poker_sessions/_session_result_fields.html.erb app/views/dashboard/show.html.erb app/views/leaderboards/show.html.erb
git commit -m "$(cat <<'EOF'
feat(view): use amount_unit_label across views

これまで "点" と固定で表示していた箇所を、グループの amount_unit に
従って "点" / "BB" を切り替えるよう変更。partial には呼び出し側から
group を明示的に渡す。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 手動確認 + push + PR 作成

**Files:** (なし - 動作確認 & PR 操作のみ)

- [ ] **Step 1: ローカルサーバ起動**

Run: `bin/dev` (バックグラウンドで起動するなら別ターミナル)
Expected: PORT 4000 で起動。

- [ ] **Step 2: ブラウザで動作確認**

1. グループ設定 (`/groups/:id/edit`) に「記録設定」セクションが表示され、「点」「BB」をセレクトできる
2. 「BB」に変更して保存できる
3. 保存後リーダーボードを開くと、累計収支末尾とチャート ytitle が「BB」表記になる
4. ポーカーセッション詳細画面の各結果と合計が「BB」表記になる
5. 新規セッション作成画面の入力欄 placeholder が「収支(BB)」になる
6. ダッシュボードのセッション一覧でも収支合計が「BB」表記になる
7. 「点」に戻すと全画面で「点」表記に戻る

- [ ] **Step 3: push**

Run: `git push -u origin feat/group-amount-unit`
Expected: 新規ブランチが push される。

- [ ] **Step 4: PR を作成**

```bash
gh pr create --base main --head feat/group-amount-unit \
  --title "feat(group): 収支の表示単位 (点 / BB) をグループごとに選べるようにする" \
  --body "$(cat <<'EOF'
## Summary
- グループごとに収支の表示単位を「点」または「BB」から選べるようにした
- グループ設定画面 (`/groups/:id/edit`) の「記録設定」から変更可能
- 数値変換はなし、表示ラベルのみが切り替わる
- デフォルトは「点」で、既存グループの挙動は変わらない

## 設計 / 計画
- 設計: `docs/superpowers/specs/2026-05-30-group-amount-unit-design.md`
- 実装計画: `docs/superpowers/plans/2026-05-31-group-amount-unit.md`

## 主な変更
- `groups` テーブルに `amount_unit` カラム (enum: point/bb) を追加
- `Group` モデルに enum を追加
- `ApplicationHelper#amount_unit_label(group)` を追加
- リーダーボード / ダッシュボード / セッション詳細 / セッションフォームの「点」表示を helper 経由に変更

## Test plan
- [x] `bundle exec rspec` 全 spec 通過
- [x] `bin/rubocop` no offenses
- [ ] ブラウザでグループ設定変更 → 全画面で単位ラベルが切り替わることを確認

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR の URL が出力される。

---

## Self-Review Notes

- **Spec coverage:**
  - データモデル (`amount_unit` enum, default point) → Task 1, 2
  - 表示ラベル切替ヘルパー → Task 3
  - 編集 UI (groups#update permit + edit view) → Task 4
  - 各 view の「点」差し替え (リーダーボード / ダッシュボード / セッション詳細 / 入力欄 placeholder) → Task 5
  - テスト (group model / helper / groups request) → Task 2, 3, 4
  - 数値変換なし → Task 5 のラベル差し替えで担保
  - スコープ外項目 → 一切実装しない
- **Placeholder scan:** 各 step に完全な実装コード/コマンドを記載済み。"TBD"・"TODO" なし。
- **Type consistency:** `amount_unit` (string enum) / `amount_unit_point?` / `amount_unit_bb?` / `amount_unit_label(group)` を全タスクで統一。
