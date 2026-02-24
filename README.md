# Scoreboard

ポーカー収支管理 Web アプリ。友人グループでセッションの記録・リーダーボード表示ができる。

## 技術スタック

| カテゴリ | 技術 |
| --- | --- |
| 言語 / FW | Ruby 4.0.1 / Rails 8.1.2 |
| DB | PostgreSQL（スキーマ: `scoreboard,public`） |
| 認証 | Devise + Google OAuth2 |
| フロントエンド | Tailwind CSS v4 / Stimulus + Turbo |
| テスト | RSpec + FactoryBot + shoulda-matchers |
| デプロイ | Fly.io（sjc リージョン） |
| CI/CD | GitHub Actions → Fly.io 自動デプロイ |

## セットアップ

前提: Ruby 4.0.1, PostgreSQL, Bundler

```bash
git clone https://github.com/eityans/scoreboard.git
cd scoreboard
cp .env.example .env  # Google OAuth 認証情報を記入
bin/setup              # 依存インストール + DB 準備
bin/dev                # 開発サーバー起動（Rails + Tailwind watch）
```

`.env` に設定する値は [Google Cloud Console](https://console.cloud.google.com/) の OAuth 2.0 クライアントから取得する。

## テスト

```bash
bundle exec rspec
```

## デプロイ

`main` ブランチへの push で GitHub Actions 経由の自動デプロイが走る。

手動デプロイ:

```bash
fly deploy
```

本番コンソール:

```bash
fly ssh console --pty -C "/rails/bin/rails console"
```

## データモデル

```text
User ──→ Membership ──→ Group
                          ├── Player (soft delete)
                          ├── PokerSession ──→ SessionResult ──→ Player
                          └── Leaderboard（集計ビュー）
```

詳細は `db/schema.rb` を参照。
