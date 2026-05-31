# PWA インストール対応 (Phase 1)

## 概要

Scoreboard アプリを PWA としてインストール可能にし、一度閲覧したページはオフラインでも表示できるようにする。アプリ固有のアイコンを用意して PWA としての見た目を整える。

## 背景

現状 Rails 8 デフォルトの PWA scaffolding (`app/views/pwa/manifest.json.erb`, `service-worker.js`) は配置されているものの、route が未定義で実際には `/manifest` も `/service-worker` も叩けない状態になっている。レイアウトの `<head>` にも `<link rel="manifest">` がない。結果として、ホーム画面追加・デスクトップインストール・オフライン閲覧のいずれも機能しない。

オフライン書き込み (フォーム送信を IndexedDB に貯めて後で同期) は Phase 2 として別 spec で扱う。本 spec は **install 可能 + read オフライン** の最小 PWA を対象とする。

## 要件

- スマホ (iOS Safari / Android Chrome) およびデスクトップ Chromium 系で PWA としてインストールできる
- インストール後はホーム画面のアイコンから起動し、`display: standalone` で起動する
- 一度オンラインで開いたページは、オフラインでも再表示できる
- 新規セッション記録などの **書き込みは対象外** (Phase 2 で扱う)。オフライン時は通常のネットワークエラーになる
- アイコンは複数折れ線で収支推移を抽象化した独自デザイン
- 既存の認証・画面動作は壊さない

## アーキテクチャ

3 つの構成要素から成る:

1. **Manifest 配信**: Rails 8 標準の `Rails::Pwa` コントローラと `app/views/pwa/manifest.json.erb` を使い、`/manifest` でブラウザに PWA メタ情報を返す。
2. **Service Worker 配信**: 同じく `/service-worker` で `app/views/pwa/service-worker.js` を返す。SW 内では network-first + cache fallback 戦略を実装。
3. **アイコン**: SVG 原画を `app/assets/images/icon.svg` で管理し、`bin/render_icons` スクリプトで PNG (192/512) を生成して `public/` に配置。

## 設計

### Routes と Layout

`config/routes.rb` に以下を追加 (`devise_for` の直後、`resources :groups` の前あたり):

```ruby
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: "json" }
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

`app/views/layouts/application.html.erb` の `<head>` 内、既存の `<link rel="apple-touch-icon">` の **直後** に追加:

```erb
<link rel="manifest" href="<%= pwa_manifest_path %>">
```

`app/javascript/application.js` の **末尾** に Service Worker 登録コードを追加:

```js
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker", { scope: "/" })
}
```

### Manifest

`app/views/pwa/manifest.json.erb` を以下に書き換え:

```erb
{
  "name": "Scoreboard",
  "short_name": "Scoreboard",
  "description": "ポーカー収支管理",
  "icons": [
    { "src": "/icon-192.png", "type": "image/png", "sizes": "192x192" },
    { "src": "/icon.png", "type": "image/png", "sizes": "512x512" },
    { "src": "/icon.png", "type": "image/png", "sizes": "512x512", "purpose": "maskable" }
  ],
  "start_url": "/",
  "display": "standalone",
  "scope": "/",
  "theme_color": "#2563eb",
  "background_color": "#f9fafb",
  "lang": "ja"
}
```

主な変更点:

- `short_name` を明示
- `description` を「ポーカー収支管理」(`apple-mobile-web-app-capable` などの既存メタと一致)
- `theme_color` を `#2563eb` (Tailwind blue-600、アプリのプライマリボタン色)
- `background_color` を `#f9fafb` (Tailwind gray-50、アプリの背景色)
- `lang` を `"ja"`
- `icons` を 192/512/512 maskable の3エントリ構成に

### Service Worker

`app/views/pwa/service-worker.js` の中身 (現状は Web Push 用のコメントのみ) を以下に置き換え:

```js
const CACHE_NAME = "scoreboard-v1"

self.addEventListener("install", () => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(
        names.filter((name) => name !== CACHE_NAME).map((name) => caches.delete(name))
      )
    )
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response.ok) {
          const clone = response.clone()
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone))
        }
        return response
      })
      .catch(() =>
        caches.match(event.request).then((cached) =>
          cached || new Response("オフラインです", {
            status: 503,
            headers: { "Content-Type": "text/plain; charset=utf-8" }
          })
        )
      )
  )
})
```

戦略の特徴:

- GET のみ介入。POST/PATCH/DELETE は素通し → オフライン時は通常のネットワークエラー (Phase 2 で改善)
- オンライン: 常にネットワーク優先 → CSRF トークンも最新が取れるため認証フォーム送信に影響しない
- オフライン: cache 命中で返却、無ければ 503 と "オフラインです" の plain text
- `CACHE_NAME` を `v2`, `v3` … と更新すれば旧キャッシュは `activate` で自動削除される

### アイコン

**原画 (SVG)** を `app/assets/images/icon.svg` に新規作成。デザイン仕様:

- 512x512 viewBox
- 背景: `#2563eb` (theme_color と同一の blue-600)、角丸 80px の正方形
- safe zone を考慮し、グラフは中央 80% (52..460 程度) に配置
- 折れ線 3 本:
  - 1 本目 (`#ffffff`): 右上がり、stroke-width 28
  - 2 本目 (`#bfdbfe` blue-200): 右下がり、stroke-width 24
  - 3 本目 (`#e0e7ff` indigo-100): 横ばい、stroke-width 20
- 各折れ線の終点に同色の `<circle r="14">` を置く

**生成スクリプト** を `bin/render_icons` に新規作成 (Ruby):

- 入力: `app/assets/images/icon.svg`
- 出力: `public/icon.svg` (コピー)、`public/icon.png` (512x512)、`public/icon-192.png` (192x192)
- ツール優先順位: `rsvg-convert` → `magick` (ImageMagick v7) → `convert` (ImageMagick v6)。いずれも見つからなければ案内メッセージを出して exit 1
- 既存の `public/icon.png` と `public/icon.svg` を上書きする
- README に「アイコン変更時は `bin/render_icons` を実行」と注記

生成された PNG/SVG は **git で管理する**。CI で PNG を再生成しない。

## エラーハンドリング

- Service Worker 登録失敗 (HTTPS でない開発環境の特定ケース、サポート外ブラウザ): silently fail で問題なし。`if ("serviceWorker" in navigator)` でガード。
- manifest の icon が 404 の場合: PWA install プロンプトが出ないが、アプリ自体は動作する → `bin/render_icons` 実行漏れに備え、CI で `public/icon.png` と `public/icon-192.png` の存在を verify (任意、過剰なら省略)。
- `bin/render_icons` 実行時にツールが無い場合: 明示的エラーメッセージで案内 (上記)。

## テスト

- `spec/requests/pwa_spec.rb` 新規:
  - `GET /manifest` が `200` を返し、Content-Type が `application/manifest+json` または `application/json`、ボディに `"Scoreboard"` を含む
  - `GET /service-worker` が `200` を返し、Content-Type が `text/javascript` または `application/javascript`、ボディに `CACHE_NAME` を含む
- Service Worker のキャッシュ挙動はブラウザ統合領域のためテスト対象外。Chrome DevTools の Application → Service Workers と Offline トグルでローカル確認する。

## スコープ外 (YAGNI)

- オフライン書き込み (フォーム送信を IndexedDB に貯めて Background Sync で同期) → **Phase 2 で別 spec**
- Push 通知 (既存の `service-worker.js` コメントアウト部分も今回は触らない)
- Web Share API
- iOS 用 splash screen 画像 (複数解像度の `apple-touch-startup-image`)
- screenshot エントリ (Chrome の install プロンプトでアプリプレビューを出す機能)
- マスカブルアイコン専用の別画像 (今回は同じ icon.png を maskable として宣言)
- ユーザーごとの manifest 動的化 (グループ名を入れる等)

## 運用

- ブランチ: `feat/pwa-install`
- マージは PR ベース (memory の `feedback-pr-workflow` に従う)
- Phase 2 (オフライン書き込み) は本 PR マージ後に別途 brainstorming して spec/plan を起こす
