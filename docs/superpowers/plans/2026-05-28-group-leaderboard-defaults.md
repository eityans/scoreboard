# Group Leaderboard Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** グループごとにリーダーボードのデフォルト設定（期間 / 最低参加回数）を保存・編集できるようにし、URL パラメータ未指定時はその設定に従って初期表示を切り替える。

**Architecture:** `groups` テーブルに `default_leaderboard_period` (enum: latest/all) と `default_leaderboard_min_sessions` (integer) の2カラムを追加。`GroupsController` に `edit/update` を追加してメンバー全員が編集可能にし、新規 `groups/edit.html.erb` で UI を提供。`LeaderboardsController` のデフォルト解決を URL params > group defaults > system fallback の優先順位で行うよう変更する。

**Tech Stack:** Rails 8.1, RSpec, PostgreSQL, Tailwind CSS

**Spec:** `docs/superpowers/specs/2026-05-28-group-leaderboard-defaults-design.md`

**Branch:** `feat/group-leaderboard-defaults`（作業開始時点で既に切られている前提）

---

## File Map

**Create:**
- `db/migrate/<timestamp>_add_leaderboard_defaults_to_groups.rb`
- `app/views/groups/edit.html.erb`

**Modify:**
- `db/schema.rb` (マイグレーション実行で自動更新)
- `app/models/group.rb`
- `app/controllers/groups_controller.rb`
- `config/routes.rb`
- `app/views/groups/show.html.erb`
- `app/controllers/leaderboards_controller.rb`
- `spec/models/group_spec.rb`
- `spec/requests/groups_spec.rb`
- `spec/requests/leaderboards_spec.rb`

---

### Task 1: グループにデフォルト設定カラムを追加するマイグレーション

**Files:**
- Create: `db/migrate/20260528110100_add_leaderboard_defaults_to_groups.rb`
- Modify: `db/schema.rb` (auto)

- [ ] **Step 1: マイグレーションファイルを作成**

`db/migrate/20260528110100_add_leaderboard_defaults_to_groups.rb`:

```ruby
class AddLeaderboardDefaultsToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :default_leaderboard_period, :string, null: false, default: "latest"
    add_column :groups, :default_leaderboard_min_sessions, :integer, null: false, default: 3
  end
end
```

- [ ] **Step 2: マイグレーションを実行**

Run: `bin/rails db:migrate`
Expected: `add_column(:groups, :default_leaderboard_period, ...)` と `add_column(:groups, :default_leaderboard_min_sessions, ...)` がそれぞれ migrated と表示される。

- [ ] **Step 3: schema.rb の更新を確認**

Run: `grep -A 12 'create_table "scoreboard.groups"' db/schema.rb`
Expected: 出力に以下を含む。
```
t.string "default_leaderboard_period", default: "latest", null: false
t.integer "default_leaderboard_min_sessions", default: 3, null: false
```

- [ ] **Step 4: テスト DB にも反映**

Run: `bin/rails db:test:prepare`
Expected: 成功 (出力なし or 軽微なログのみ)。

- [ ] **Step 5: コミット**

```bash
git add db/migrate/20260528110100_add_leaderboard_defaults_to_groups.rb db/schema.rb
git commit -m "$(cat <<'EOF'
feat(group): add leaderboard default columns to groups

リーダーボードのデフォルト期間と最低参加回数をグループごとに保存できるよう
カラムを追加。デフォルトは "latest" と 3 で、これまでの挙動を維持する。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Group モデルに enum / validation を追加 (TDD)

**Files:**
- Modify: `app/models/group.rb`
- Modify: `spec/models/group_spec.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/models/group_spec.rb` を以下で置き換える:

```ruby
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
end
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/models/group_spec.rb`
Expected: `default_period_latest?` などの enum 由来メソッドが未定義のため、`NoMethodError` や `ArgumentError` で複数失敗する。

- [ ] **Step 3: モデルに enum / validation を追加**

`app/models/group.rb` を以下で置き換える:

```ruby
class Group < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :players, dependent: :destroy
  has_many :poker_sessions, dependent: :destroy

  enum :default_leaderboard_period, { latest: "latest", all: "all" }, prefix: :default_period

  validates :name, presence: true
  validates :invitation_token, presence: true, uniqueness: true
  validates :default_leaderboard_min_sessions,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  before_validation :generate_invitation_token, on: :create

  private

  def generate_invitation_token
    self.invitation_token ||= SecureRandom.urlsafe_base64(16)
  end
end
```

- [ ] **Step 4: テスト通過を確認**

Run: `bundle exec rspec spec/models/group_spec.rb`
Expected: 8 examples, 0 failures.

- [ ] **Step 5: コミット**

```bash
git add app/models/group.rb spec/models/group_spec.rb
git commit -m "$(cat <<'EOF'
feat(group): add enum and validation for leaderboard defaults

default_leaderboard_period を latest/all の enum とし、min_sessions に
numericality バリデーションを追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: GroupsController に edit/update を追加 (TDD)

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/groups_controller.rb`
- Modify: `spec/requests/groups_spec.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/requests/groups_spec.rb` の `describe "POST /groups"` ブロックの直後 (一番下の `context "when user is not a member"` の前) に以下を追加する:

```ruby
  describe "GET /groups/:id/edit" do
    context "when user is a member" do
      let(:group) { create(:group, created_by: user) }

      before { create(:membership, user: user, group: group, role: "owner") }

      it "returns a successful response" do
        get edit_group_path(group)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not a member" do
      let(:group) { create(:group) }

      it "redirects to groups index" do
        get edit_group_path(group)
        expect(response).to redirect_to(groups_path)
      end
    end
  end

  describe "PATCH /groups/:id" do
    let(:group) { create(:group, created_by: user) }

    before { create(:membership, user: user, group: group, role: "owner") }

    context "with valid params" do
      it "updates leaderboard defaults" do
        patch group_path(group), params: {
          group: {
            default_leaderboard_period: "all",
            default_leaderboard_min_sessions: 1
          }
        }
        group.reload
        expect(group.default_leaderboard_period).to eq("all")
        expect(group.default_leaderboard_min_sessions).to eq(1)
      end

      it "redirects to the group" do
        patch group_path(group), params: { group: { name: "renamed" } }
        expect(response).to redirect_to(group_path(group))
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity for an empty name" do
        patch group_path(group), params: { group: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns unprocessable entity for an invalid min_sessions" do
        patch group_path(group), params: { group: { default_leaderboard_min_sessions: 0 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user is not a member" do
      let(:other_group) { create(:group) }

      it "redirects to groups index" do
        patch group_path(other_group), params: { group: { name: "hack" } }
        expect(response).to redirect_to(groups_path)
      end
    end
  end
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/requests/groups_spec.rb`
Expected: `edit_group_path` / `PATCH /groups/:id` のルートが無いため `NoMethodError: undefined method 'edit_group_path'` や `ActionController::RoutingError` で失敗する。

- [ ] **Step 3: routes.rb に edit/update を追加**

`config/routes.rb` の `resources :groups, only: [ :index, :show, :new, :create ] do` を以下に変更:

```ruby
  resources :groups, only: [ :index, :show, :new, :create, :edit, :update ] do
```

- [ ] **Step 4: GroupsController に edit/update を追加**

`app/controllers/groups_controller.rb` を以下で置き換える:

```ruby
class GroupsController < ApplicationController
  before_action :set_group, only: [ :show, :edit, :update ]
  before_action :authorize_member!, only: [ :show, :edit, :update ]

  def index
    @groups = current_user.groups
  end

  def show
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)
    @group.created_by = current_user

    if @group.save
      @group.memberships.create!(user: current_user, role: "owner")
      redirect_to @group, notice: "グループを作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @group.update(group_params)
      redirect_to @group, notice: "グループの設定を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def authorize_member!
    redirect_to groups_path, alert: "このグループにはアクセスできません" unless current_user.groups.include?(@group)
  end

  def group_params
    params.require(:group).permit(:name, :default_leaderboard_period, :default_leaderboard_min_sessions)
  end
end
```

- [ ] **Step 5: ビュー未作成のため `edit` テストはまだ通らない事を確認**

Run: `bundle exec rspec spec/requests/groups_spec.rb -e "GET /groups/:id/edit"`
Expected: `ActionView::MissingTemplate (Missing template groups/edit ...)` で失敗。これは Task 4 で view を作って解消する。`PATCH /groups/:id` 系のテストは通るはず。

Run: `bundle exec rspec spec/requests/groups_spec.rb -e "PATCH /groups/:id"`
Expected: 5 examples, 0 failures.

- [ ] **Step 6: コミット**

ここでは edit ビューが未完成だがコントローラ側のロジックは確定したのでまずコミットする。

```bash
git add config/routes.rb app/controllers/groups_controller.rb spec/requests/groups_spec.rb
git commit -m "$(cat <<'EOF'
feat(group): add edit and update actions

メンバー全員がグループ設定を編集できるよう edit/update を追加。
group_params にデフォルト設定2項目を permit。view は次のコミットで追加する。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: groups/edit.html.erb を作成

**Files:**
- Create: `app/views/groups/edit.html.erb`

- [ ] **Step 1: ビューを作成**

`app/views/groups/edit.html.erb`:

```erb
<h1 class="text-2xl font-bold mb-6">グループ設定</h1>

<div class="bg-white shadow-sm rounded-xl border border-gray-100 p-6 max-w-md">
  <%= form_with(model: @group, class: "space-y-5") do |form| %>
    <% if @group.errors.any? %>
      <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
        <% @group.errors.full_messages.each do |message| %>
          <p><%= message %></p>
        <% end %>
      </div>
    <% end %>

    <div>
      <%= form.label :name, "グループ名", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= form.text_field :name, class: "w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition" %>
    </div>

    <fieldset class="border-t border-gray-100 pt-5">
      <legend class="text-sm font-semibold text-gray-700 mb-3">リーダーボードのデフォルト</legend>

      <div class="space-y-3">
        <div>
          <%= form.label :default_leaderboard_period, "期間", class: "block text-sm font-medium text-gray-700 mb-1" %>
          <%= form.select :default_leaderboard_period,
                [["最新クォーター", "latest"], ["全期間", "all"]],
                {},
                class: "w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition" %>
        </div>

        <div>
          <%= form.label :default_leaderboard_min_sessions, "最低参加回数", class: "block text-sm font-medium text-gray-700 mb-1" %>
          <%= form.number_field :default_leaderboard_min_sessions, min: 1, step: 1,
                class: "w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition" %>
          <p class="text-xs text-gray-500 mt-1">この回数以上参加したプレイヤーがチャートに表示されます。</p>
        </div>
      </div>
    </fieldset>

    <%= form.submit "保存する", class: "w-full bg-blue-600 text-white py-2.5 px-4 rounded-lg hover:bg-blue-700 font-medium cursor-pointer transition" %>
  <% end %>
</div>

<div class="mt-4">
  <%= link_to "← #{@group.name}", group_path(@group), class: "text-sm text-gray-500 hover:text-gray-700" %>
</div>
```

- [ ] **Step 2: edit テストの通過を確認**

Run: `bundle exec rspec spec/requests/groups_spec.rb`
Expected: 13 examples, 0 failures（全テスト通過。`GET /groups/:id/edit` のテストも含む）。

- [ ] **Step 3: コミット**

```bash
git add app/views/groups/edit.html.erb
git commit -m "$(cat <<'EOF'
feat(group): add edit form for group settings

グループ名とリーダーボードのデフォルト設定 (期間/最低参加回数) を編集する
フォームを追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: グループ詳細に「設定」リンクを追加

**Files:**
- Modify: `app/views/groups/show.html.erb`

- [ ] **Step 1: ボタンエリアにリンクを追加**

`app/views/groups/show.html.erb` の以下のブロック:

```erb
<div class="flex flex-wrap gap-2 mb-6">
  <%= link_to "セッション記録", new_group_poker_session_path(@group), class: "bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 text-sm font-medium transition" %>
  <%= link_to "リーダーボード", group_leaderboard_path(@group), class: "bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-sm font-medium transition" %>
  <%= link_to "プレイヤー管理", group_players_path(@group), class: "bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200 text-sm font-medium transition" %>
</div>
```

を以下に置き換える:

```erb
<div class="flex flex-wrap gap-2 mb-6">
  <%= link_to "セッション記録", new_group_poker_session_path(@group), class: "bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 text-sm font-medium transition" %>
  <%= link_to "リーダーボード", group_leaderboard_path(@group), class: "bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-sm font-medium transition" %>
  <%= link_to "プレイヤー管理", group_players_path(@group), class: "bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200 text-sm font-medium transition" %>
  <%= link_to "設定", edit_group_path(@group), class: "bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200 text-sm font-medium transition" %>
</div>
```

- [ ] **Step 2: グループ詳細のテストが引き続き通ることを確認**

Run: `bundle exec rspec spec/requests/groups_spec.rb -e "GET /groups/:id"`
Expected: 既存のテストが通る。

- [ ] **Step 3: コミット**

```bash
git add app/views/groups/show.html.erb
git commit -m "$(cat <<'EOF'
feat(group): add settings link from group page

グループ詳細画面から設定ページへのリンクを追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: リーダーボードのデフォルト解決をグループ設定に従わせる (TDD)

**Files:**
- Modify: `app/controllers/leaderboards_controller.rb`
- Modify: `spec/requests/leaderboards_spec.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/requests/leaderboards_spec.rb` の `context "with quarterly filter" do` ブロックの直後 (`context "with min_sessions filter" do` の前) に以下を追加:

```ruby
    context "with group defaults" do
      let(:player_a) { create(:player, group: group, display_name: "Alice") }
      let(:player_b) { create(:player, group: group, display_name: "Bob") }

      before do
        q4_session = create(:poker_session, group: group, created_by: user, played_on: Date.new(2025, 10, 15))
        create(:session_result, poker_session: q4_session, player: player_a, amount: 500)

        q1_session = create(:poker_session, group: group, created_by: user, played_on: Date.new(2026, 1, 20))
        create(:session_result, poker_session: q1_session, player: player_b, amount: 300)
      end

      it "uses the group's 'all' period default when params are missing" do
        group.update!(default_leaderboard_period: "all")

        get group_leaderboard_path(group)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alice")
        expect(response.body).to include("Bob")
      end

      it "uses the group's 'latest' period default when params are missing" do
        group.update!(default_leaderboard_period: "latest")

        get group_leaderboard_path(group)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("2026Q1")
      end

      it "lets URL params override the group default" do
        group.update!(default_leaderboard_period: "all")

        get group_leaderboard_path(group), params: { quarter: "2025Q4" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alice")
        expect(response.body).not_to include("Bob")
      end

      it "uses the group's min_sessions default when param is missing" do
        group.update!(default_leaderboard_min_sessions: 5)

        get group_leaderboard_path(group)
        expect(assigns(:min_sessions)).to eq(5)
      end

      it "lets URL min_sessions param override the group default" do
        group.update!(default_leaderboard_min_sessions: 5)

        get group_leaderboard_path(group), params: { min_sessions: 2 }
        expect(assigns(:min_sessions)).to eq(2)
      end
    end
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/requests/leaderboards_spec.rb -e "with group defaults"`
Expected: グループの `default_period` を `all` にしても期間で絞り込まれた結果 (`Bob` を含まない) になっているため、`'Bob' を含む` を期待するテストで失敗する。

- [ ] **Step 3: LeaderboardsController を修正**

`app/controllers/leaderboards_controller.rb` の `resolve_quarter` メソッドを以下で置き換える:

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
```

同じファイルの `build_chart_data` 内の `@min_sessions` 行 (現状 `@min_sessions = [ params.fetch(:min_sessions, 3).to_i, 1 ].max`) を以下に置き換える:

```ruby
    @min_sessions = [ params.fetch(:min_sessions, @group.default_leaderboard_min_sessions).to_i, 1 ].max
```

- [ ] **Step 4: テスト通過を確認**

Run: `bundle exec rspec spec/requests/leaderboards_spec.rb`
Expected: 全テスト通過。

Run: `bundle exec rspec`
Expected: 全 spec 通過 (前タスクまでで増えたテストも含む)。

- [ ] **Step 5: lint**

Run: `bin/rubocop`
Expected: no offenses detected.

- [ ] **Step 6: コミット**

```bash
git add app/controllers/leaderboards_controller.rb spec/requests/leaderboards_spec.rb
git commit -m "$(cat <<'EOF'
feat(leaderboard): respect group defaults when params are missing

URL パラメータ未指定時に group.default_leaderboard_period と
group.default_leaderboard_min_sessions を初期値として使用するよう変更。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: ブラウザでの手動確認 + push + PR 作成

**Files:** (なし - 動作確認 & PR 操作のみ)

- [ ] **Step 1: ローカルサーバ起動**

Run: `bin/dev` (バックグラウンドで起動するなら別ターミナル)
Expected: PORT 4000 で起動。

- [ ] **Step 2: ブラウザで動作確認**

以下をブラウザで確認する:

1. グループ詳細に「設定」リンクが表示されているか
2. 「設定」を押すと `/groups/:id/edit` に遷移し、フォームが表示されるか
3. デフォルト期間を「全期間」、最低参加回数を `1` にして保存できるか
4. 保存後グループ詳細に戻り、リーダーボードにアクセスすると全期間 + 1回以上のプレイヤーが表示されるか
5. URL に `?quarter=2025Q4&min_sessions=3` を直接付けた場合、その値が優先されるか
6. 無効値（min_sessions=0）でバリデーションエラーが出るか

- [ ] **Step 3: push**

Run: `git push -u origin feat/group-leaderboard-defaults`
Expected: 新規ブランチが push される。

- [ ] **Step 4: PR を作成**

```bash
gh pr create --base main --head feat/group-leaderboard-defaults \
  --title "feat(group): リーダーボードのデフォルト設定をグループごとに保存できるようにする" \
  --body "$(cat <<'EOF'
## Summary
- グループごとにリーダーボードのデフォルト期間 (最新クォーター / 全期間) と最低参加回数を保存できるようにした
- メンバー全員がグループ設定画面 (`/groups/:id/edit`) から編集可能
- URL パラメータが指定された場合はそちらを優先し、既存の挙動を壊さない

## 設計
詳細は [docs/superpowers/specs/2026-05-28-group-leaderboard-defaults-design.md](../blob/feat/group-leaderboard-defaults/docs/superpowers/specs/2026-05-28-group-leaderboard-defaults-design.md) を参照。

## Test plan
- [x] `bundle exec rspec` 全 spec 通過
- [x] `bin/rubocop` no offenses
- [x] ブラウザで設定変更 → リーダーボード初期表示が変わることを確認
- [x] URL パラメータ指定がグループのデフォルトを上書きすることを確認

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR の URL が出力される。

---

## Self-Review Notes

- **Spec coverage:**
  - データモデル (default_leaderboard_period enum / min_sessions validation) → Task 1, 2
  - UI 画面遷移 (groups#edit, settings link) → Task 3, 4, 5
  - デフォルト解決 (URL params > group defaults > system fallback) → Task 6
  - テスト (group / groups request / leaderboards request) → Task 2, 3, 6
  - YAGNI スコープ外項目 → そのまま実装しない
- **Placeholder scan:** 各 step に完全な実装コードを記載済み。"TBD"・"TODO" なし。
- **Type consistency:** `default_leaderboard_period` (string enum) と `default_leaderboard_min_sessions` (integer) のカラム名を全タスクで統一。enum predicate は `default_period_all?` / `default_period_latest?` で統一。
