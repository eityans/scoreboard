# グループごとの収支単位設定 (点 / BB)

## 概要

グループごとに収支記録の表示単位を「点」または「BB」(Big Blind) から選べるようにする。デフォルトは「点」。

## 背景

現状、収支の単位は全グループで固定的に「点」と表示している。ポーカー文脈ではキャッシュゲームで遊ぶグループは BB 単位で集計するのが一般的で、グループの遊び方に合わせて単位ラベルを切り替えたいというニーズがある。

## 要件

- グループのメンバー全員が設定を編集できる (既存の `groups#edit` を流用)
- 既存の `default_leaderboard_*` 設定と同じ画面・同じ仕組みで設定する
- 「点」と「BB」は **表示単位のみの切り替え**。数値変換は行わない (例: `100` を保存している場合、設定を BB にしたら `100 BB` と表示される)
- 既存データはそのまま。単位を変えても DB 上の `amount` 値は変わらない

## データモデル

`groups` テーブルに1カラムを追加する:

```ruby
add_column :groups, :amount_unit, :string, null: false, default: "point"
```

`Group` モデル:

```ruby
enum :amount_unit, { point: "point", bb: "bb" }, prefix: :amount_unit
```

`amount_unit_point?` / `amount_unit_bb?` 述語が使えるようになる。

## 表示の切り替え

### ヘルパー

`ApplicationHelper` に追加:

```ruby
def amount_unit_label(group)
  group.amount_unit_bb? ? "BB" : "点"
end
```

引数は `Group` インスタンス。

### 「点」が出ている既存箇所

| ファイル | 該当箇所 |
| --- | --- |
| `app/views/poker_sessions/show.html.erb` | 各プレイヤー結果の「点」と合計の「点」 |
| `app/views/dashboard/show.html.erb` | 「収支合計: …点」 |
| `app/views/leaderboards/show.html.erb` | ランキング行末尾の「点」とチャート `ytitle: "累計 (点)"` |
| `app/views/poker_sessions/_session_result_fields.html.erb` | 入力欄の `placeholder: "収支(点)"` |

これらを `amount_unit_label(group)` で置換する。`group` は各 view で次の通り解決する:

- `poker_sessions/show.html.erb`: `@poker_session.group` (`@group` も使える)
- `dashboard/show.html.erb`: 各 `session.group` (セッションを跨ぐので一行ずつ評価)
- `leaderboards/show.html.erb`: `@group`
- `_session_result_fields.html.erb`: partial の呼び出し側 `poker_sessions/_form.html.erb` から `locals: { group: @group }` で渡す

partial の依存をハッキリさせるため、`form.object.poker_session.group` のような遠回しな解決ではなく明示的に渡す方針。

## 編集 UI

`app/views/groups/edit.html.erb` に「記録設定」fieldset を追加 (既存の「リーダーボードのデフォルト」fieldset とは独立):

```erb
<fieldset class="border-t border-gray-100 pt-5">
  <legend class="text-sm font-semibold text-gray-700 mb-3">記録設定</legend>

  <div>
    <%= form.label :amount_unit, "収支の単位", class: "block text-sm font-medium text-gray-700 mb-1" %>
    <%= form.select :amount_unit,
          [["点", "point"], ["BB", "bb"]],
          {},
          class: "w-full border border-gray-300 rounded-lg px-3 py-2 ..." %>
    <p class="text-xs text-gray-500 mt-1">表示単位のみ切り替わります。既存データの数値は変わりません。</p>
  </div>
</fieldset>
```

`GroupsController#group_params` の permit に `:amount_unit` を追加する。

## テスト

- `spec/models/group_spec.rb`: `amount_unit` のデフォルト `"point"`、enum の predicate (`amount_unit_point?` / `amount_unit_bb?`)、未知の値を弾く
- `spec/requests/groups_spec.rb`: PATCH /groups/:id で `amount_unit` を更新できる
- `spec/helpers/application_helper_spec.rb`: `amount_unit_label(group)` が `point` グループに対して `"点"`、`bb` グループに対して `"BB"` を返す

## スコープ外 (YAGNI)

- 単位間の数値換算 (点 ⇄ BB、レート保持)
- グループ作成フォーム (`new.html.erb`) への追加 (edit から変更可能なので不要)
- 単位ごとの精度設定 (現状の `decimal(12, 1)` のまま)
- 個別セッション / 個別結果ごとに単位を変える機能
- I18n 対応 (現状日本語固定でリテラルを直接書いているコードベースに合わせる)

## 運用

- ブランチ: `feat/group-amount-unit`
- PR ベース運用 (memory の `feedback-pr-workflow` に従う)
