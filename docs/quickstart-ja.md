# 公開0.4.0の日本語 Quick Start

## DataでRailsの集計Serviceを呼ぶ

ClientとServerは両方とも公開RubyGems `a2a-rails = 0.4.0`を使います。
Git/path候補は不要です。CIは公開版の取得元、版、配布GemのSHA256
`77b36d4c1cc0db5ab028a35556f1495596f930a25922ff2bf29cde761d45132a`
を照合します。Serverの固定コミットは `5f6d3bfb76c174484ac5b03eac8cfe72038ee3be` です。
過去の0.3.0／Git候補の検証記録は、公開0.4.0の結果とは区別します。

PR #4のマージ前はclone後に `git switch feat/structured-report-candidate` でPRを選びます。マージ後はmainを使えます。

```sh
git clone https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
bundle install
RAILS_ENV=test bundle exec rake test
# 許可を得た独立HTTPS report AgentのURL・originを設定した後:
bundle exec ruby bin/report
bundle exec ruby bin/report --invalid-month
```

送信Dataは`{"year":2026,"month":10,"department_id":123}`です。
Serverの既存RouterがDataをreport Skill、textをreply Skillへ振り分けます。
reportは`input_modes: ["application/json"]`を宣言し、HandlerがRailsの
`Reports::SalesSummary`を呼びます。同期実行・MemoryStoreを使い、DB・queue・
LLM・外部サービスは追加しません。固定売上12,000円、18,000円、5,000円から、
Data Artifactで**3件・合計35,000円（JPY）**を返します。他の年月・部署は対象外です。

返却項目はyear、month、department_id、sales_count、total_amount、currencyです。
Clientは送信後にGetTaskで一度再取得し、同じ集計結果を確認して表示します。
月13の条件は`TASK_STATE_REJECTED`となりreportを返しません。自動retryやpollingはしません。
同じServiceを直接呼ぶ場合は集計だけで、A2A経由では通信・Skill選択・Task保存・
Artifact・別Clientからの再取得が加わります。最短のEcho例は`bin/probe`に残ります。

Dataは最上位object、mediaType省略時はapplication/json、明示時も同値に限定します。
text/Data混在は今回対象外です。既存Hash/Array出力は維持されます。
AP2正式拡張、File入力、SSE、Task再開、本番公開はこの候補に含みません。

実通信には既存の一時証明書・TLS bridge・`real_https_echo.rb`を使います。
通常Clientのlocalhost拒否を解除しません。[英語の実行手順](report.md)に、
Serverの起動とClientからのTLS実通信手順があります。

## 通常操作と実通信の確認

## 構成

| 役割 | リポジトリ | 公開Gem |
| --- | --- | --- |
| A2A Client | [a2a-rails-client-demo](https://github.com/cuichangquan/a2a-rails-client-demo) | `0.4.0` |
| A2A Server (Echo / Report) | [a2a-rails-demo](https://github.com/cuichangquan/a2a-rails-demo) | `0.4.0` |

Clientは `server_enabled = false` に設定し、受信側A2Aルートを持ちません。Serverは別リポジトリで正式版`0.4.0`に更新したEchoデモを利用します。両アプリは異なるBundler環境で公開Gemをロードします。

## ① 基本テストを実行

Ruby 3.4.10、Bundlerが必要です。Railsホストの`net-imap`は修正版`~>0.5.15`を明示指定します。

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

1. Client (0.4.0) とServer (0.4.0) を **それぞれ公開RubyGemsからインストール**。Serverは固定したマージ済みコミットをチェックアウト。
2. Serverを `127.0.0.1:3000` のみで起動。
3. 一時証明書で `127.0.0.1:3443` にTLSブリッジを起動。
4. ClientがAgent Card取得→SendMessage→Task/Artifact→GetTask/ListTasks→直接Messageを実行。レポートの3件35,000円、Data履歴、月13の拒否も確認。
5. 終了したTaskのCancelTaskエラーと実際のEcho Service戻り値を確認。
6. テスト専用プロセスを終了。

```text
Rails Client 0.4.0
      │   HTTPS (検証付きTLS / socket IP pinning)
      ▼
テスト専用TLSブリッジ（127.0.0.1:3443）
      │   CI内部のみでHTTP
      ▼
独立Rails Echo Server 0.4.0（127.0.0.1:3000）
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

## 公開Gemの検証記録

2026-11-15、Linux x86_64 / Ruby 3.4.12 / Rails 8.1.4で、両アプリが
上記SHA256の公開0.4.0 Gemを読み込むことを確認しました。Clientは14 tests /
80 assertions、production起動拒否、別プロセス間TLSの25項目がすべて成功しました。
条件送信・3件35,000円・Data履歴/GetTask・月13拒否と既存Echo/directの経路を含みます。
CIはRuby 3.4.10で別途実行するため、ローカル結果とは区別してPRの該当commitを確認してください。
