# PWA Install (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scoreboard を PWA としてインストール可能にし、一度オンラインで閲覧したページはオフラインでも表示できるようにする。Phase 1 は read オフラインまでをカバーし、オフライン書き込みは Phase 2 で別途。

**Architecture:** Rails 8 標準の `Rails::Pwa` コントローラ経由で `/manifest` と `/service-worker` を配信。Service Worker は素 JS で network-first + cache fallback を実装。アイコンは SVG 原画を git 管理し、`bin/render_icons` スクリプトで PNG 192/512 を生成する。

**Tech Stack:** Rails 8.1, RSpec, vanilla Service Worker (no Workbox), librsvg または ImageMagick (PNG 生成)

**Spec:** `docs/superpowers/specs/2026-05-31-pwa-install-design.md`

**Branch:** `feat/pwa-install`（作業開始時点で既に切られている前提）

---

## File Map

**Create:**
- `spec/requests/pwa_spec.rb`
- `app/assets/images/icon.svg`
- `bin/render_icons`
- `public/icon-192.png` (bin/render_icons の生成物)

**Overwrite (既存ファイルを置き換え):**
- `public/icon.png` (新デザインの 512px PNG)
- `public/icon.svg` (新デザインの SVG)
- `app/views/pwa/manifest.json.erb`
- `app/views/pwa/service-worker.js`

**Modify (部分追記):**
- `config/routes.rb`
- `app/views/layouts/application.html.erb`
- `app/javascript/application.js`

---

### Task 1: PWA routes を追加 (TDD)

**Files:**
- Create: `spec/requests/pwa_spec.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: 失敗するテストを書く**

`spec/requests/pwa_spec.rb` を新規作成:

```ruby
require "rails_helper"

RSpec.describe "PWA" do
  describe "GET /manifest" do
    it "returns the PWA manifest as JSON" do
      get "/manifest"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to match(/(application\/manifest\+json|application\/json)/)
      expect(response.body).to include("Scoreboard")
    end
  end

  describe "GET /service-worker" do
    it "returns the service worker as JavaScript" do
      get "/service-worker"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to match(/javascript/)
      expect(response.body).to include("CACHE_NAME")
    end
  end
end
```

- [ ] **Step 2: テストを走らせて失敗を確認**

Run: `bundle exec rspec spec/requests/pwa_spec.rb`
Expected: routes 未定義のため `ActionController::RoutingError (No route matches [GET] "/manifest")` で 2 失敗。

- [ ] **Step 3: routes.rb に PWA エンドポイントを追加**

`config/routes.rb` 内の `get "up" => "rails/health#show", as: :rails_health_check` 行の **直後** に以下を追加:

```ruby
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: "json" }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

- [ ] **Step 4: テスト通過を確認 (manifest だけ通る、SW は CACHE_NAME 未実装でまだ失敗)**

Run: `bundle exec rspec spec/requests/pwa_spec.rb`
Expected: 1 example passes (manifest)、1 failure (service-worker は `CACHE_NAME` を含まないため)。これは Task 4 で解消する。

- [ ] **Step 5: コミット**

```bash
git add config/routes.rb spec/requests/pwa_spec.rb
git commit -m "$(cat <<'EOF'
feat(pwa): expose manifest and service-worker routes

Rails 8 デフォルトの Rails::Pwa コントローラに対するルートを追加し、
/manifest と /service-worker でアクセスできるようにする。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Manifest を整える

**Files:**
- Overwrite: `app/views/pwa/manifest.json.erb`

- [ ] **Step 1: manifest.json.erb を書き換え**

`app/views/pwa/manifest.json.erb` の **全内容** を以下に置き換える:

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

- [ ] **Step 2: manifest のテストが通ることを確認**

Run: `bundle exec rspec spec/requests/pwa_spec.rb -e "GET /manifest"`
Expected: 1 example, 0 failures。

- [ ] **Step 3: コミット**

```bash
git add app/views/pwa/manifest.json.erb
git commit -m "$(cat <<'EOF'
feat(pwa): update manifest with app branding

short_name / description / theme_color (#2563eb) / background_color
(#f9fafb) / lang (ja) を整え、192/512/512-maskable のアイコン3エントリを
宣言。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Layout に manifest link を追加

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: `<head>` に manifest link を追加**

`app/views/layouts/application.html.erb` の以下の行:

```erb
    <link rel="apple-touch-icon" href="/icon.png">
```

の **直後** に以下を挿入:

```erb
    <link rel="manifest" href="<%= pwa_manifest_path %>">
```

- [ ] **Step 2: 既存の request spec が壊れていないことを確認**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb spec/requests/groups_spec.rb`
Expected: 全テスト通過 (layout のレンダリングが壊れていないことを確認)。

- [ ] **Step 3: コミット**

```bash
git add app/views/layouts/application.html.erb
git commit -m "$(cat <<'EOF'
feat(pwa): link manifest from application layout

ブラウザが PWA メタ情報を取得できるよう <link rel="manifest"> を追加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Service Worker を実装 (TDD)

**Files:**
- Overwrite: `app/views/pwa/service-worker.js`

- [ ] **Step 1: service-worker.js を書き換え**

`app/views/pwa/service-worker.js` の **全内容** を以下に置き換える:

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

- [ ] **Step 2: service-worker のテストが通ることを確認**

Run: `bundle exec rspec spec/requests/pwa_spec.rb`
Expected: 2 examples, 0 failures (`CACHE_NAME` が含まれるようになり service-worker テストも通る)。

- [ ] **Step 3: コミット**

```bash
git add app/views/pwa/service-worker.js
git commit -m "$(cat <<'EOF'
feat(pwa): implement network-first service worker

GET リクエストに対して network-first + cache fallback を実装。
オンライン時は常にネットワーク優先で取得し成功すれば cache に格納、
オフライン時は cache から返す。POST 等は介入しない。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Service Worker 登録コードを application.js に追加

**Files:**
- Modify: `app/javascript/application.js`

- [ ] **Step 1: 現状の application.js を確認**

Run: `cat app/javascript/application.js`
Expected: importmap で controllers などを読み込んでいる行が並んでいる。

- [ ] **Step 2: ファイル末尾に SW 登録コードを追加**

`app/javascript/application.js` の **末尾** (最後の `import` の後の空行に続けて) 以下を追加:

```js

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker", { scope: "/" })
}
```

- [ ] **Step 3: lint**

Run: `bin/rubocop config/routes.rb spec/requests/pwa_spec.rb`
Expected: no offenses detected (JS は rubocop 対象外なのでこの2ファイルのみ)。

- [ ] **Step 4: コミット**

```bash
git add app/javascript/application.js
git commit -m "$(cat <<'EOF'
feat(pwa): register service worker on page load

navigator.serviceWorker.register で /service-worker を root scope で
登録。Service Worker 未対応ブラウザは silently skip。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: アイコン SVG と PNG 生成スクリプトを追加

**Files:**
- Create: `app/assets/images/icon.svg`
- Create: `bin/render_icons`
- Overwrite: `public/icon.png` (bin/render_icons 実行で)
- Overwrite: `public/icon.svg` (bin/render_icons 実行で)
- Create: `public/icon-192.png` (bin/render_icons 実行で)

- [ ] **Step 1: 原画 SVG を作成**

`app/assets/images/icon.svg` を新規作成:

```svg
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <rect width="512" height="512" rx="80" ry="80" fill="#2563eb"/>
  <polyline fill="none" stroke="#ffffff" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"
    points="80,360 180,300 280,260 380,180 440,140"/>
  <circle cx="440" cy="140" r="16" fill="#ffffff"/>
  <polyline fill="none" stroke="#bfdbfe" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"
    points="80,200 180,240 280,300 380,340 440,400"/>
  <circle cx="440" cy="400" r="14" fill="#bfdbfe"/>
  <polyline fill="none" stroke="#e0e7ff" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"
    points="80,280 180,290 280,270 380,290 440,280"/>
  <circle cx="440" cy="280" r="12" fill="#e0e7ff"/>
</svg>
```

- [ ] **Step 2: bin/render_icons スクリプトを作成**

`bin/render_icons` を新規作成:

```ruby
#!/usr/bin/env ruby
require "fileutils"

ROOT = File.expand_path("..", __dir__)
SRC = File.join(ROOT, "app/assets/images/icon.svg")

unless File.exist?(SRC)
  warn "Source SVG not found: #{SRC}"
  exit 1
end

OUTPUTS = [
  { dest: File.join(ROOT, "public/icon.png"), size: 512 },
  { dest: File.join(ROOT, "public/icon-192.png"), size: 192 }
].freeze

def find_renderer
  return :rsvg if system("which rsvg-convert > /dev/null 2>&1")
  return :magick if system("which magick > /dev/null 2>&1")
  return :convert if system("which convert > /dev/null 2>&1")

  nil
end

renderer = find_renderer
unless renderer
  warn "No SVG-to-PNG converter found."
  warn "Install one of:"
  warn "  brew install librsvg     # provides rsvg-convert (recommended)"
  warn "  brew install imagemagick # provides magick / convert"
  exit 1
end

OUTPUTS.each do |out|
  ok = case renderer
       when :rsvg
         system("rsvg-convert", "-w", out[:size].to_s, "-h", out[:size].to_s, SRC, "-o", out[:dest])
       when :magick
         system("magick", "-background", "none", "-density", "300", SRC, "-resize", "#{out[:size]}x#{out[:size]}", out[:dest])
       when :convert
         system("convert", "-background", "none", "-density", "300", SRC, "-resize", "#{out[:size]}x#{out[:size]}", out[:dest])
       end
  abort("Failed to render #{out[:dest]} with #{renderer}") unless ok
  puts "Generated #{out[:dest]}"
end

FileUtils.cp(SRC, File.join(ROOT, "public/icon.svg"))
puts "Copied #{File.join(ROOT, "public/icon.svg")}"
```

- [ ] **Step 3: スクリプトに実行権限を付与**

Run: `chmod +x bin/render_icons`
Expected: 出力なし (成功)。

- [ ] **Step 4: スクリプトを実行して PNG を生成**

Run: `bin/render_icons`
Expected: `Generated .../public/icon.png` / `Generated .../public/icon-192.png` / `Copied .../public/icon.svg` の3行が表示される。エラーで失敗した場合はメッセージに従ってツールを brew install してから再実行。

- [ ] **Step 5: 生成された PNG のサイズを確認**

Run: `file public/icon.png public/icon-192.png`
Expected: `public/icon.png: PNG image data, 512 x 512` / `public/icon-192.png: PNG image data, 192 x 192`。

- [ ] **Step 6: コミット**

```bash
git add app/assets/images/icon.svg bin/render_icons public/icon.png public/icon.svg public/icon-192.png
git commit -m "$(cat <<'EOF'
feat(pwa): add scoreboard icon with line chart motif

複数折れ線で収支推移を抽象化した青背景のアイコンを追加。SVG 原画は
app/assets/images/icon.svg、bin/render_icons で librsvg または
ImageMagick を使って public/ に PNG (192, 512) を生成する。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 手動確認 + push + PR

**Files:** (なし - 動作確認 & PR 操作のみ)

- [ ] **Step 1: ローカルサーバ起動**

Run: `bin/dev` (バックグラウンドで起動するなら別ターミナル)
Expected: PORT 4000 で起動。

- [ ] **Step 2: ブラウザで動作確認**

Chrome (or Edge) で `http://localhost:4000` を開き、以下を確認:

1. **DevTools → Application → Manifest**:
   - `name: Scoreboard`, `theme_color: #2563eb`, アイコン (192/512) が表示される
   - エラーが出ていない
2. **DevTools → Application → Service Workers**:
   - `/service-worker` が "activated and running" 状態
3. **DevTools → Application → Cache Storage**:
   - 数ページ閲覧後、`scoreboard-v1` に GET レスポンスが格納される
4. **DevTools → Network → Offline トグル ON**:
   - 一度開いたページをリロードすると cache から再表示される
   - 一度も開いていないページは "オフラインです" のテキストが返る
5. **インストールプロンプト**:
   - URL バーの右側に install アイコンが出る (Chrome デスクトップ) → クリックでインストールできる
6. **iOS Safari の手動確認** (任意): 共有 → ホーム画面に追加で標準名 "Scoreboard" + 新アイコンが表示される

- [ ] **Step 3: push**

Run: `git push -u origin feat/pwa-install`
Expected: 新規ブランチが push される。

- [ ] **Step 4: PR を作成**

```bash
gh pr create --base main --head feat/pwa-install \
  --title "feat(pwa): インストール対応 (Phase 1) + read オフライン + 新アイコン" \
  --body "$(cat <<'EOF'
## Summary
- Scoreboard を PWA としてインストール可能にした (ホーム画面追加 / デスクトップインストール)
- Service Worker (network-first + cache fallback) で一度オンラインで開いたページがオフラインでも表示できるようにした
- 複数折れ線で収支推移を抽象化した新アイコンに刷新

## スコープ
本 PR は Phase 1 (install + read オフライン) のみ。オフライン書き込み (フォーム送信を IndexedDB に貯めて Background Sync で同期) は Phase 2 として別途 brainstorming/spec を起こす。

## 設計 / 計画
- 設計: \`docs/superpowers/specs/2026-05-31-pwa-install-design.md\`
- 実装計画: \`docs/superpowers/plans/2026-05-31-pwa-install.md\`

## 主な変更
- \`config/routes.rb\` に \`/manifest\` と \`/service-worker\` を追加
- \`app/views/pwa/manifest.json.erb\` を app branding に合わせて更新
- \`app/views/pwa/service-worker.js\` に network-first + cache fallback を実装
- \`app/views/layouts/application.html.erb\` に \`<link rel="manifest">\` を追加
- \`app/javascript/application.js\` で Service Worker を登録
- \`app/assets/images/icon.svg\` (新規アイコン原画) と \`bin/render_icons\` (PNG 生成スクリプト) を追加

## Test plan
- [x] \`bundle exec rspec spec/requests/pwa_spec.rb\` 通過
- [x] \`bin/rubocop\` no offenses
- [ ] DevTools で manifest / service worker / cache / offline 表示を確認
- [ ] Chrome デスクトップで install プロンプト
- [ ] iOS Safari でホーム画面に追加

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR の URL が出力される。

---

## Self-Review Notes

- **Spec coverage:**
  - Routes / Layout / SW 登録 → Task 1, 3, 5
  - Manifest → Task 2
  - Service Worker (network-first + cache fallback) → Task 4
  - アイコン (SVG + 生成スクリプト + PNG) → Task 6
  - テスト (request spec for manifest / service-worker) → Task 1, 4
  - スコープ外 (オフライン書き込み, push 通知 等) → 一切実装しない (PR 本文と spec で明示)
- **Placeholder scan:** 各 step に完全な実装コードを記載済み。"TBD"・"TODO" なし。
- **Type consistency:**
  - `CACHE_NAME = "scoreboard-v1"` を Task 4 と Task 1 spec で統一
  - manifest 内のアイコンパス (`/icon-192.png`, `/icon.png`) と Task 6 の生成先 (`public/icon-192.png`, `public/icon.png`) が一致
  - route name (`pwa_manifest_path`) が Task 1 と Task 3 で整合
