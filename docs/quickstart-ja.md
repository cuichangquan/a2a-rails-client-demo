# 0.5.0候補の日本語 Quick Start

これは**未公開の候補**です。両アプリは `candidate.json` に記録した同じGemの
完全SHA・版をGitから読み込みます。RubyGemsに0.5.0が公開済みとは扱いません。
Railsは8.1.4.1です。既存Echo・直接Message・条件の揃った1回集計は維持します。

## 基本テスト

Ruby 3.4.10、Bundlerを用意し、候補PRが未統合の間はそのブランチを選びます。

```sh
git clone https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
git switch feat/task-continuation-demo
bundle install
bundle exec ruby bin/verify_candidate
RAILS_ENV=test bundle exec rake test
```

Clientは `server_enabled = false` で受信ルートを持ちません。Serverは別プロセス。
DB・queue・LLM・外部サービス・新規クラウド資源は不要です。

## 質問→回答→同じTaskで結果取得

1. `year: 2026, month: 10` をDataで送ります。
2. `TASK_STATE_INPUT_REQUIRED` と、`status.message.parts` 内の部署IDの質問を取得します。
3. 保存したTask IDを `task_id` に指定して `department_id: 123` を送ります。
4. 同じTask・contextがCOMPLETEDとなり、3件・合計35,000円を返します。

```ruby
result = client.send_message(message: {
  message_id: SecureRandom.uuid, role: "ROLE_USER",
  parts: [{ data: { "year" => 2026, "month" => 10 } }]
})
id = result.task.fetch(:id)
waiting = client.get_task(id: id, history_length: 0)
question = waiting.dig(:status, :message, :parts)
answer = client.send_message(message: {
  message_id: SecureRandom.uuid, role: "ROLE_USER", task_id: id,
  parts: [{ data: { "department_id" => 123 } }]
})
final = client.get_task(id: id, history_length: 0)
```

Data内のキーは文字列、プロトコルDTOはsymbolです。元の年月と追加回答はServer
アプリが許可した項目だけ結合します。Gemは任意JSONを自動マージしません。
`message` は今回の入力、`context[:history]` は今回を含む履歴です。質問用の
`InputRequired` はGem自身の型で、HandlerにSDK型を要求しません。
通常のHash出力は業務データのままです。Task IDは会話全体で同じで、Gem内部の
実行ターンIDは古いJobの後着による上書きを防ぐために別管理します。

許可済みの独立HTTPS Agentを設定した場合だけ、次を実行できます。

```sh
bundle exec ruby bin/probe
bundle exec ruby bin/report
bundle exec ruby bin/report --invalid-month
bundle exec ruby bin/continue_report
bundle exec ruby bin/continue_report --reask
bundle exec ruby bin/continue_report --cancel
bundle exec ruby bin/continue_report --after-completion # new answer is refused
```

`--reask` は年→月→部署の順に2回質問、`--cancel` は入力待ち中のキャンセルです。
月13は従来どおりREJECTED。完了・キャンセル後の新しい回答はUnsupportedOperation (-32004)で拒否されます。
入力はobject Dataのみ、text/Data混在入力は追加しません。質問の出力はtextとData。
応答の `history_length: 0` は保存入力を消しません。Serverは同期MemoryStoreなので、
**再起動すると入力待ちTaskを失います**。永続Storeや実workerの保証はGem本体の検証対象です。

## 実TLS通信

[専用CI](../.github/workflows/interop-https.yml)は独立Serverの完全SHAを固定し、
両側の候補Gemの取得元・版・SHAとcandidate.jsonの一致を照合します。その後、
ループバックHTTP Serverと一時証明書のTLSブリッジを別プロセスで起動します。
Echo・1回集計・質問回答・再質問・キャンセル・終端Taskへの新しい回答の拒否を確認します。
通常ClientのHTTPS、宛先、CA、SNI・ホスト名検証は緩めません。テスト限定でloopback
ソケットを指定し、通常のloopback拒否とホスト名不一致の拒否も検証します。
[英語の詳細手順](report.md)参照。公開DNS/公開CA、本番環境、A2A全仕様認証ではありません。

通信失敗時の自動再送・汎用pollingはしません。送信済みか不明なら状態を確認し、
Gemの同一messageId再送契約に従います。無条件に新しいIDで再送しません。
固定質問と合成集計値のみ表示し、認証情報・任意Parts・例外本文はログに出しません。
認証を使う場合は `.env.example` のtokenと正確な宛先originを必ずセットにします。
Serverは匿名のローカルデモであり、業務認可や外部処理のexactly-onceを保証しません。
SSE・OAuth・AUTH_REQUIRED・AP2拡張・本番公開は対象外です。

## 正式公開後の別作業

本人の別途承認と実際のGem公開後にのみ、両デモを公開Gemへ固定し、配布物を照合、
HTTP／TLSを再検証します。候補検証の成功はマージ・タグ・公開・デプロイの承認ではありません。
過去の検証記録は以下に保存していますが、新しい候補の成功証明には使いません。

## 過去の公開Gem検証記録（Rails 8.1.4）

2026-11-15、Linux x86_64 / Ruby 3.4.12 / Rails 8.1.4で、両アプリが
公開0.4.0 Gem（SHA256 `77b36d4c1cc0db5ab028a35556f1495596f930a25922ff2bf29cde761d45132a`）を読み込むことを確認しました。Clientは14 tests /
80 assertions、production起動拒否、別プロセス間TLSの25項目がすべて成功しました。
条件送信・3件35,000円・Data履歴/GetTask・月13拒否と既存Echo/directの経路を含みます。
CIはRuby 3.4.10で別途実行するため、ローカル結果とは区別してPRの該当commitを確認してください。

ローカルServerは `36b1414cc4231812e7516394e602dbdfc73a34f2` で、固定したremote
`5f6d3bfb76c174484ac5b03eac8cfe72038ee3be` とtreeが一致します。別途、
[CI 43706040060](https://github.com/cuichangquan/a2a-rails-client-demo/actions/runs/43706040060)は
Client `63f37ed7a8c56e666c3039d6851df889932d6494`、Ruby 3.4.10、固定remote Serverで成功しました。


## Rails 8.1.4.1の検証

2026-11-15、Linux x86_64 / Ruby 3.4.12でRailsと12個の構成Gemがすべて
8.1.4.1であることを確認しました。a2a-railsは公開0.4.0の同一SHA256を維持。
Client 14 tests / 80 assertions、production起動拒否、別プロセスTLS25項目が成功しました。
ローカルServer `19a592b21bb793eb03938d48ca672b0737f9e011` は新しい固定remote
`68d929cd93494acd163fb9d12c6309ca916068b7` とtreeが一致し、remoteの明示fetchも確認しました。
CIはRuby 3.4.10を使い、両アプリのRails版を照合します。ローカル結果と区別してPRの最終commitの結果を確認してください。
