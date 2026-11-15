# 公開0.3.0と構造化レポート候補の日本語 Quick Start

## 0.4.0候補: DataでRailsの集計Serviceを呼ぶ

新しいレポート例は**未公開の固定Gem SHA**を`Gemfile.candidate`で使用します。
ClientとServerの両方に同じ候補が必要です。通常のGemfileは公開0.3.0のEcho用で、
この候補をRubyGemsから取得できるという意味ではありません。以下のStep32記録は
従来の公開版検証であり、新しい候補の検証結果とは区別します。

候補Gemは`e13b3ef06698990c6a7b9e1522bf09f7c38e31c5`、独立Serverは
`db100a2b05c14f0ec693918593adaa141a43cfce`へ固定しています。候補ソースの
version定数は公開準備前の0.3.0のままなので、公開RubyGems版とはGit SHAで区別します。
既存のoffline/TLS workflowは公開版と候補を別jobで検証し、各job上限は8分です。

```sh
git clone --branch feat/structured-report-candidate --single-branch https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
BUNDLE_GEMFILE=Gemfile.candidate bundle install
BUNDLE_GEMFILE=Gemfile.candidate RAILS_ENV=test bundle exec rake test
# 既存のURL・origin設定で、許可を得た独立HTTPS report Agentに送信する場合:
BUNDLE_GEMFILE=Gemfile.candidate bundle exec ruby bin/report
BUNDLE_GEMFILE=Gemfile.candidate bundle exec ruby bin/report --invalid-month
```

マージ前はこの候補PR branchを使い、公開mainから候補ファイルを取得できるとは
扱いません。Serverもfeat/structured-report-demo branchの上記固定SHAを使います。

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
通常Clientのlocalhost拒否を解除しません。ローカル実行も可能な既存手順と、
固定SHAの照合、条件・結果・GetTask・月13の確認範囲は
[英語の候補手順](report-candidate.md)に記載しています。
公開後は両デモを新しい公開Gemへ固定し、RubyGems由来の確認と同じ検証を再実行します。

2026-11-15のローカルLinux/Ruby3.4.12では、Clientは公開版・候補とも14 tests /
80 assertions、Server業務テストは5 / 17で失敗なしでした。候補の実HTTP・
実TLSで条件送信、3件35,000円、GetTask、月13拒否と既存Echo/directの経路も確認済みです。
CIはリポジトリ指定のRuby3.4.10で別途検証し、最終commitの結果は対応PRを参照してください。

## 以下は公開0.3.0のEcho基準手順（Step32）

## 構成

| 役割 | リポジトリ | 公開Gem |
| --- | --- | --- |
| A2A Client | [a2a-rails-client-demo](https://github.com/cuichangquan/a2a-rails-client-demo) | `0.3.0` |
| A2A Server (Echo) | [a2a-rails-demo](https://github.com/cuichangquan/a2a-rails-demo) | `0.3.0` |

Clientは `server_enabled = false` に設定し、受信側A2Aルートを持ちません。Serverは別リポジトリで正式版`0.3.0`に更新したEchoデモを利用します。両アプリは異なるBundler環境で公開Gemをロードします。

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

1. Client (0.3.0) とServer (0.3.0) を **それぞれ公開RubyGemsからインストール**。Serverは固定したマージ済みコミットをチェックアウト。
2. Serverを `127.0.0.1:3000` のみで起動。
3. 一時証明書で `127.0.0.1:3443` にTLSブリッジを起動。
4. ClientがAgent Card取得→SendMessage→Task/Artifact→GetTask/ListTasks→直接Messageを実行。
5. 終了したTaskのCancelTaskエラーと実際のEcho Service戻り値を確認。
6. テスト専用プロセスを終了。

```text
Rails Client 0.3.0
      │   HTTPS (検証付きTLS / socket IP pinning)
      ▼
テスト専用TLSブリッジ（127.0.0.1:3443）
      │   CI内部のみでHTTP
      ▼
独立Rails Echo Server 0.3.0（127.0.0.1:3000）
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
