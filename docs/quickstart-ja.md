# Step 30 — 日本語 Quick Start / 再現手順

## 構成

| 役割 | リポジトリ | 公開Gem |
| --- | --- | --- |
| A2A Client | [a2a-rails-client-demo](https://github.com/cuichangquan/a2a-rails-client-demo) | `0.3.0.rc1` |
| A2A Server (Echo) | [a2a-rails-demo](https://github.com/cuichangquan/a2a-rails-demo) | `0.2.0` |

Clientは `server_enabled = false` に設定し、受信側A2Aルートを持ちません。Serverは既存のEchoデモを変更せず利用します。

## ① 基本テストを実行

Ruby 3.4.10、Bundlerが必要です。

```bash
git clone https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
bundle install
RAILS_ENV=test bundle exec rake test
```

## ② Rails同士の実HTTPS通信を再現

[GitHub Actions: Independent Rails-to-Rails HTTPS](https://github.com/cuichangquan/a2a-rails-client-demo/actions/workflows/interop-https.yml) から既存の成功ログを閲覧できます。権限がある場合は **Run workflow** で再実行できます。

GitHub CLIの場合：

```bash
gh workflow run interop-https.yml --repo cuichangquan/a2a-rails-client-demo
gh run list --repo cuichangquan/a2a-rails-client-demo --workflow interop-https.yml --limit 3
```

実際にCI内で実行すること：

1. Client (0.3.0.rc1) とServer (0.2.0) を **それぞれ公開RubyGemsからインストール**。
2. Serverを `127.0.0.1:3000` のみで起動。
3. 一時証明書で `127.0.0.1:3443` にTLSブリッジを起動。
4. ClientがAgent Card取得→SendMessage→Task/Artifact→GetTask/ListTasks→直接Messageを実行。
5. 終了したTaskのCancelTaskエラーと実際のEcho Service戻り値を確認。
6. テスト専用プロセスを終了。

```text
Rails Client 0.3.0.rc1
      │   HTTPS (検証付きTLS / socket IP pinning)
      ▼
テスト専用TLSブリッジ（127.0.0.1:3443）
      │   CI内部のみでHTTP
      ▼
独立Rails Echo Server 0.2.0（127.0.0.1:3000）
      │
      ▼
Echo::Reply → Task / Artifact / Message
```

**注意：** 既存ServerのAgent CardはローカルHTTPを宣言するため、ブリッジではJSONRPCの接続URLだけをテスト用HTTPSへ変更します。通常のClientはプライベートIPを拒否するので、**CI内のテストコード限定**でループバックIPと一時CAを設定しています。これは公開DNS/公開CAの本番相当環境を証明するものではありません。

## ③ 承認済みの外部Agentに接続する

公開DNS・信頼できるCAのHTTPS接続先があり、実際にリクエストを送信する許可を得ている場合のみ：

```bash
export A2A_AGENT_CARD_URL='https://YOUR_APPROVED_AGENT/.well-known/agent-card.json'
export A2A_ALLOWED_ORIGINS='https://YOUR_APPROVED_AGENT'
bundle exec ruby bin/probe
```

認証が必要な場合は **認証情報と正確なHTTPS originをセットで** 指定してください。Agent CardとRPCで異なるスコープを設定できます。具体的な変数名は [`.env.example`](../.env.example) に記載しています。トークンをGit/CIログへ登録しないでください。

## トラブルシューティング

| 症状 | 確認すること |
| --- | --- |
| URL設定エラー | `https://` かつ許可済みoriginに完全一致しているか |
| Credential originエラー | Tokenとその宛先originをセットで指定したか |
| DNS/IP拒否 | ローカル/private/metadata IPが含まれていないか。保護を解除しない |
| TLSエラー | 証明書、有効期限、SNI、ホスト名の一致 |
| Timeout | Send/Cancelは実行済みの可能性あり。**自動再送しない** |
| Taskがない | A2AのSendMessageはTaskまたは直接Messageが正常な応答 |
| ローカルServerに直結できない | Clientの本番向けSSRF制限の仕様。CI専用TLS検証を使う |

本番公開の認証、権限、監査、耐久性、レート制限については [Issue #11](https://github.com/cuichangquan/a2a-rails/issues/11) を参照してください。
