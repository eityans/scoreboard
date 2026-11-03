# Live Session Entries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ゲーム中に参加、リバイ、退出を記録し、終了時に記録から各プレイヤーの収支を計算して `session_results` に書き込めるようにする。

**Architecture:** `poker_sessions` に `status` と `recorded_live` を足し、記録を `session_entries` に持つ。記録からの計算は PORO の `SessionLedger` に置き、`session_results` への書き込みは `PokerSession#sync_results!` の 1 か所にまとめる。記録の保存と削除のコールバックから `sync_results!` を呼ぶので、記録の変更と同じトランザクションで結果が更新される。

**Tech Stack:** Rails 8.1, PostgreSQL, RSpec, FactoryBot, Tailwind CSS, Stimulus

**Spec:** `docs/superpowers/specs/2026-10-27-live-session-entries-design.md`

## Global Constraints

- 金額は `decimal(12,1)`。表示は `format_amount` と `amount_unit_label(group)` を使う
- 収支 = 退出の合計 − 参加の合計 − リバイの合計 + 調整の合計
- 着席中 = 最後の参加より後に退出の記録が無い
- 終了できる条件：参加の記録が 1 件以上あり、着席中の人がいない
- `recorded_live` は「ゲームを始める」で作ったときだけ `true`。作った後は変えない
- 権限はグループのメンバー（既存の `authorize_member!` と同じ判定）
- ボタンは既存の `btn` 系ユーティリティ（最小 44px）を使う
- 記録の並び順は `created_at`。記録欄は新しい順に出す

## Review Focus

- 終了後に退出を消して着席中の人ができる：セッションが `in_progress` に戻り、`session_results` が消える（Task 3 のテスト）
- 退出したあと再び参加した人：収支が式どおりに計算され、最後の参加の後に退出が無ければ着席中と判定される（Task 2 のテスト）
- `in_progress` のセッションに今の編集フォームから収支を送る：`session_results` が作られない（Task 6 のテスト）
- 2 人が同時に終了する：`with_lock` で直列化し、2 回目は何も変えずに成功扱いで詳細画面に戻る（Task 5 のテスト）
- セッションを消す：記録のコールバックが結果を作り直さずに消える（Task 1 の `dependent: :delete_all` と Task 3 のテスト）

---

## File Map

**Create:**
- `db/migrate/20261103100000_add_live_recording_to_poker_sessions.rb`
- `db/migrate/20261103100100_create_session_entries.rb`
- `app/models/session_entry.rb`
- `app/models/session_ledger.rb`
- `app/controllers/session_entries_controller.rb`
- `app/views/poker_sessions/_live.html.erb`（ゲーム中の画面と、終了後の記録欄）
- `app/views/poker_sessions/_live_edit_form.html.erb`
- `app/views/session_entries/new.html.erb`, `edit.html.erb`, `_form.html.erb`
- `spec/factories/session_entries.rb`
- `spec/models/session_entry_spec.rb`, `spec/models/session_ledger_spec.rb`
- `spec/requests/session_entries_spec.rb`

**Modify:**
- `app/models/poker_session.rb`, `app/models/player.rb`
- `app/controllers/poker_sessions_controller.rb`, `leaderboards_controller.rb`, `dashboard_controller.rb`
- `config/routes.rb`
- `app/views/poker_sessions/show.html.erb`, `index.html.erb`, `edit.html.erb`
- `app/views/groups/show.html.erb`, `app/views/dashboard/show.html.erb`
- `spec/models/poker_session_spec.rb`, `spec/requests/poker_sessions_spec.rb`, `spec/requests/dashboard_spec.rb`, `spec/requests/leaderboards_spec.rb`

---

### Task 1: スキーマとモデルの関連

**Files:**
- Create: 2 つのマイグレーション, `app/models/session_entry.rb`, `spec/factories/session_entries.rb`, `spec/models/session_entry_spec.rb`
- Modify: `app/models/poker_session.rb`, `app/models/player.rb`, `spec/factories/poker_sessions.rb`

**Interfaces:**
- Produces:
  - `PokerSession` の `enum :status, { in_progress: "in_progress", completed: "completed" }`（既定値 `completed`）と `recorded_live`（boolean、既定値 false）
  - `PokerSession has_many :session_entries, dependent: :delete_all`（`delete_all` にするのは、Task 3 の記録のコールバックをセッション削除時に走らせないため）
  - `Player has_many :session_entries, dependent: :restrict_with_error`
  - `SessionEntry`：`belongs_to :poker_session`, `:player`, `:recorded_by (User)`、`enum :kind, { join: "join", rebuy: "rebuy", cash_out: "cash_out", adjustment: "adjustment" }`、`validates :amount, presence: true`、`join` / `rebuy` / `cash_out` の `amount` は 0 以上、`player` は `poker_session.group` のプレイヤーであること
  - factory `:session_entry`（`kind { "join" }`, `amount { 300 }`）、factory `:poker_session` に trait `:live`（`status { "in_progress" }`, `recorded_live { true }`）

- [ ] **Step 1: テストを書く**（`spec/models/session_entry_spec.rb`）
  - `it { is_expected.to belong_to(:recorded_by).class_name("User") }`
  - `rebuy` で `amount: -1` は invalid、`adjustment` で `amount: -1` は valid
  - 別グループのプレイヤーを指定すると invalid
- [ ] **Step 2: 失敗を確認** — `bundle exec rspec spec/models/session_entry_spec.rb` → `uninitialized constant SessionEntry`
- [ ] **Step 3: マイグレーションとモデルを書く**。カラム定義は spec の「データモデル」節のとおり。`bin/rails db:migrate` で `db/schema.rb` を更新する
- [ ] **Step 4: 通過を確認** — 同じコマンドで PASS、`bundle exec rspec` 全体も PASS
- [ ] **Step 5: コミット** — `feat(session): add session entries and live recording columns`

### Task 2: 記録から収支を計算する `SessionLedger`

**Files:**
- Create: `app/models/session_ledger.rb`, `spec/models/session_ledger_spec.rb`

**Interfaces:**
- Consumes: `SessionEntry`（Task 1）
- Produces:
  - `SessionLedger.new(entries)`（`entries` は `SessionEntry` の配列。並びは `created_at` 昇順を前提にする）
  - `#rows -> Array<SessionLedger::Row>`（登場順）
  - `SessionLedger::Row = Data.define(:player, :buy_in_total, :rebuy_count, :cash_out_total, :balance, :seated, :last_cash_out)`（`seated` は boolean、`last_cash_out` は最後の退出の点数か nil）
  - `#balances -> Hash{Integer(player_id) => BigDecimal}`
  - `#any_seated? -> Boolean`, `#any_join? -> Boolean`

- [ ] **Step 1: テストを書く**
  - 参加 300、リバイ 300 を 2 回、退出 300 → `balance == -600`, `buy_in_total == 900`, `rebuy_count == 2`, `seated == false`
  - 参加 300、退出 500、参加 300 → `seated == true`、`balance == -100`
  - 参加 300、退出 300、調整 +50 → `balance == 50`
  - 調整だけを持つプレイヤー → `seated == false`
- [ ] **Step 2: 失敗を確認** — `bundle exec rspec spec/models/session_ledger_spec.rb`
- [ ] **Step 3: 実装する**。`seated` は「最後の `join` の位置より後に `cash_out` があるか」で決める
- [ ] **Step 4: 通過を確認**
- [ ] **Step 5: コミット** — `feat(session): compute balances from session entries`

### Task 3: 結果の書き込みと終了

**Files:**
- Modify: `app/models/poker_session.rb`, `app/models/session_entry.rb`, `spec/models/poker_session_spec.rb`

**Interfaces:**
- Consumes: `SessionLedger`（Task 2）
- Produces:
  - `PokerSession#ledger -> SessionLedger`（`session_entries.order(:created_at, :id)` から作る）
  - `PokerSession#finishable? -> Boolean`（`in_progress?` かつ `ledger.any_join?` かつ `!ledger.any_seated?`）
  - `PokerSession#finish! -> Boolean`（`with_lock` の中で `finishable?` を見直し、偽なら false を返す。真なら `completed` にして `sync_results!`）
  - `PokerSession#sync_results!`：`recorded_live?` かつ `completed?` のときだけ動く。着席中の人がいれば `in_progress` に戻して `session_results` を全部消す。いなければ `session_results` を `ledger.balances` と一致させる（無いプレイヤーは作り、記録から消えたプレイヤーは消し、値を更新する）
  - `PokerSession#participant_count -> Integer`（`in_progress?` なら記録に出てくるプレイヤーの人数、それ以外は `session_results.size`）
  - `SessionEntry` の `after_save` と `after_destroy` で `poker_session.sync_results!` を呼ぶ

- [ ] **Step 1: テストを書く**（`spec/models/poker_session_spec.rb`）
  - 全員退出済みで `finish!` → true、`completed?`、`session_results` の値が `ledger.balances` と一致
  - 着席中の人がいると `finish!` → false、`session_results` は 0 件
  - `completed` の記録方式のセッションで退出を 1 件消す → `in_progress?` に戻り、`session_results` が 0 件
  - `completed` の記録方式のセッションで退出の点数を直す → `session_results` の値が追従する
  - 後入力方式のセッションでは `sync_results!` が `session_results` を変えない
  - 記録を持つ `completed` のセッションを `destroy!` → 例外なく消え、`SessionResult.count == 0`
- [ ] **Step 2: 失敗を確認** — `bundle exec rspec spec/models/poker_session_spec.rb`
- [ ] **Step 3: 実装する**
- [ ] **Step 4: 通過を確認**
- [ ] **Step 5: コミット** — `feat(session): sync results from entries and finish live sessions`

### Task 4: ゲームを始める、ゲーム中の画面、記録の追加と修正と削除

**Files:**
- Create: `app/controllers/session_entries_controller.rb`, `app/views/session_entries/*`, `app/views/poker_sessions/_live.html.erb`, `spec/requests/session_entries_spec.rb`
- Modify: `config/routes.rb`, `app/controllers/poker_sessions_controller.rb`, `app/views/poker_sessions/show.html.erb`, `index.html.erb`, `spec/requests/poker_sessions_spec.rb`

**Interfaces:**
- Consumes: `PokerSession#ledger`, `#finishable?`（Task 3）
- Produces:
  - ルート：`resources :poker_sessions do post :start, on: :collection; patch :finish, on: :member; resources :session_entries, only: [ :new, :create, :edit, :update, :destroy ] end`
  - `PokerSessionsController#start`：`played_on: Date.current, status: :in_progress, recorded_live: true, created_by: current_user` で作り、詳細画面へリダイレクト
  - `SessionEntriesController`：`new` は `params[:kind]` を受ける。保存後はセッション詳細へリダイレクト。`recorded_by` は作成時の `current_user`。メンバー判定は `PokerSessionsController` と同じ
  - 点数の初期値：`new` で、そのセッションの直前の `join` の `amount` を入れる（無ければ空）

`show.html.erb` は `@poker_session.recorded_live?` のとき `_live` を描く。`_live` は spec の「ゲーム中の画面」の順（卓にいる人の一覧、「参加」「リバイ」「退出」ボタン、記録欄、「セッションを終了する」ボタン）で並べる。`completed` のときは今の収支の表示の下に、記録欄と記録を足すボタンを出す。記録のフォームには `inline-player` コントローラで「新しいプレイヤー」を付ける。セッション一覧の「新規記録」の隣に `button_to "ゲームを始める"` を置く。

- [ ] **Step 1: request spec を書く**
  - `POST start` → `PokerSession.last` が `in_progress?` かつ `recorded_live?`、詳細へリダイレクト
  - `POST session_entries`（`kind: "rebuy", player_id:, amount: 300`）→ 記録が 1 件増え、`recorded_by == user`
  - `PATCH session_entries/:id` で点数を変える、`DELETE` で消える
  - ゲーム中の詳細画面に「セッションを終了する」と記録した人の名前が出る
  - メンバーでないユーザーは `POST session_entries` で `groups_path` にリダイレクトされ、記録が増えない
- [ ] **Step 2: 失敗を確認** — `bundle exec rspec spec/requests/session_entries_spec.rb spec/requests/poker_sessions_spec.rb`
- [ ] **Step 3: 実装する**
- [ ] **Step 4: 通過を確認**し、`bin/rails s` でスマホ幅の画面を目で確認する
- [ ] **Step 5: コミット** — `feat(session): record entries during a live session`

### Task 5: セッションを終了する

**Files:**
- Modify: `app/controllers/poker_sessions_controller.rb`, `spec/requests/poker_sessions_spec.rb`

**Interfaces:**
- Consumes: `PokerSession#finish!`（Task 3）
- Produces: `PokerSessionsController#finish`。`finish!` が true なら notice「セッションを終了しました」、false なら alert「全員の退出を記録してから終了してください」で詳細へリダイレクト。すでに `completed` なら何もせず詳細へリダイレクト

- [ ] **Step 1: request spec を書く** — 全員退出済みなら `completed` になり `session_results` ができる。着席中の人がいれば `in_progress` のまま。`completed` のセッションに 2 回目の `PATCH finish` を送っても `session_results` の件数が変わらない
- [ ] **Step 2: 失敗を確認**
- [ ] **Step 3: 実装する**。「セッションを終了する」ボタンは `finishable?` が偽のとき disabled にする
- [ ] **Step 4: 通過を確認**
- [ ] **Step 5: コミット** — `feat(session): finish live sessions`

### Task 6: 記録方式のセッションの編集画面

**Files:**
- Create: `app/views/poker_sessions/_live_edit_form.html.erb`
- Modify: `app/controllers/poker_sessions_controller.rb`, `app/views/poker_sessions/edit.html.erb`, `spec/requests/poker_sessions_spec.rb`, `app/models/poker_session.rb`

**Interfaces:**
- Produces:
  - `PokerSession#correct_results!(amounts_by_player_id, recorded_by:)`：トランザクションの中で、値が変わったプレイヤーごとに `新しい収支 − 今の収支` の `adjustment` を作る（`sync_results!` はコールバックで走る）
  - `update` の分岐：後入力方式のセッションは今のまま。記録方式のセッションは `played_on` と `note` だけを `poker_session_params` から受け、`params[:results]`（`{ player_id => amount }`）を `correct_results!` に渡す。`in_progress` のときは `played_on` と `note` だけを受け、`results` と `session_results_attributes` は無視する
  - `edit.html.erb`：記録方式のセッションは `_live_edit_form` を描く。`completed` なら日付、メモ、プレイヤーごとの収支欄（参加者の追加と削除の操作は出さない）。`in_progress` なら日付とメモだけ

- [ ] **Step 1: request spec を書く**
  - `completed` の記録方式のセッションで収支を −600 から −500 に直す → `adjustment` が `amount == 100` で 1 件でき、`session_results` が −500
  - 値を変えずに保存 → `adjustment` が増えない
  - `in_progress` のセッションに `session_results_attributes` 付きで `PATCH` → `session_results` が 0 件のまま、`note` は更新される
- [ ] **Step 2: 失敗を確認**
- [ ] **Step 3: 実装する**
- [ ] **Step 4: 通過を確認**
- [ ] **Step 5: コミット** — `feat(session): correct live session results via adjustment entries`

### Task 7: 一覧と集計でのゲーム中のセッションの扱い

**Files:**
- Modify: `app/views/poker_sessions/index.html.erb`, `app/views/groups/show.html.erb`, `app/views/dashboard/show.html.erb`, `app/controllers/dashboard_controller.rb`, `app/controllers/leaderboards_controller.rb`, 対応する request spec

**Interfaces:**
- Consumes: `PokerSession#participant_count`（Task 3）、`PokerSession.completed` スコープ（Task 1 の enum）

セッション一覧、グループ詳細の最近のセッション、ダッシュボードの最近のセッションでは、`in_progress` のセッションに「ゲーム中」のバッジを付け、人数を `participant_count` で出す。ダッシュボードのグループごとの回数は `completed` のセッションだけを数える。リーダーボードの `resolve_quarter` と `build_chart_data` は `@group.poker_sessions.completed` を使う。ダッシュボードの `includes` に `:session_entries` を足す。

- [ ] **Step 1: request spec を書く**
  - セッション一覧とダッシュボードに「ゲーム中」と出る
  - `in_progress` のセッションしか無い四半期は、リーダーボードの期間の選択肢に出ない
- [ ] **Step 2: 失敗を確認**
- [ ] **Step 3: 実装する**
- [ ] **Step 4: 通過を確認** — `bundle exec rspec` 全体と `bin/rubocop`
- [ ] **Step 5: コミット** — `feat(session): show live sessions in lists and exclude them from leaderboard`
