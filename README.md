# a2a-rails-client-demo — Rails 8 A2A outbound Client

A standalone **Client-only Rails 8 application** demonstrating the public
[`a2a-rails 0.3.0.rc1`](https://rubygems.org/gems/a2a-rails/versions/0.3.0.rc1)
prerelease Gem. It sends A2A v1.0 Agent Card discovery and JSON-RPC requests to
a separate approved Agent, while never serving an inbound A2A endpoint.

- Gem and roadmap: https://github.com/cuichangquan/a2a-rails
- Independent [Rails Server Echo demo](https://github.com/cuichangquan/a2a-rails-demo)
  (currently pinned to released stable 0.2.0; **not modified**)
- Work tracker: [Step 30 Issue #117](https://github.com/cuichangquan/a2a-rails/issues/117)

> **Local development/test only.** This Client host refuses production boot.
> Do not weaken published Gem SSL validation, IP pinning, SSRF policy,
> HTTP redirects, or auth-origin boundaries to connect to localhost.

## Architecture

```text
Rails 8 Client-only app                         Independent A2A Agent
  AgentClientDemo::Probe
          |
  A2A::Rails::Client
          |               approved public DNS / HTTPS
          +---- Agent Card discovery -------------> /.well-known/agent-card.json
          +---- JSON-RPC A2A v1.0 ----------------> advertised RPC URL
          <---- Task or direct Message -----------+
           (SendMessage, GetTask, ListTasks)
```

The Client's Rails app sets `config.server_enabled = false`. It
does not register a local Agent or Task Store and has no inbound
`/.well-known/agent-card.json` or `/a2a` route.

## Prerequisites

- Ruby **3.4.10**, Rails **8.1.4**, Bundler
- Published `a2a-rails = 0.3.0.rc1` from RubyGems, **not** Git checkout
- For real remote checks, an approved A2A v1.0 JSON-RPC Agent reachable on a
  **public-destination IP, public-DNS hostname, valid CA-issued HTTPS certificate**
- No external AI provider, database, Redis, Docker, or GCP required for offline tests

## Quick Start — run offline tests

```bash
git clone https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
bundle install
RAILS_ENV=test bundle exec rake test
```

The CI workflow also verifies RubyGems origin and exact installed Gem version,
both missing inbound routes, Task/direct Message behavior with a stub Client,
and refusal to boot in Rails production mode.

**Offline tests do not establish a real remote HTTPS exchange.**

## Run against an approved independent A2A Server

```bash
export A2A_AGENT_CARD_URL='https://YOUR_APPROVED_AGENT/.well-known/agent-card.json'
export A2A_ALLOWED_ORIGINS='https://YOUR_APPROVED_AGENT'
# Include the exact separately advertised RPC origin too, if different.
bundle exec ruby bin/probe
```

If the approved RPC endpoint requires auth, set **both** `A2A_RPC_TOKEN`
and `A2A_RPC_CREDENTIAL_ORIGIN` scoped to the RPC origin.
If Agent Card discovery needs auth, additionally set
`A2A_CARD_TOKEN` and `A2A_CARD_CREDENTIAL_ORIGIN` scoped to the Card origin.
See [`.env.example`](.env.example) for names. The sample never automatically
reads or loads the example file.

Expected *shape*, assuming a compatible Echo Agent (actual remote outcome
may differ):

```json
{
  "agent": "Echo Agent",
  "protocol": "A2A v1.0 JSON-RPC",
  "samples": [
    {
      "kind": "task",
      "task_id": "...",
      "state": "TASK_STATE_COMPLETED",
      "fetched_state": "TASK_STATE_COMPLETED",
      "artifacts_count": 1,
      "listed_tasks": 1
    },
    {"kind": "message", "message_id": "...", "parts_count": 1}
  ]
}
```

`AgentClientDemo::Probe` sends two requests, one normal and one with
`direct:` prefix to demonstrate both supported SendMessage return kinds.
The real remote Agent chooses the outcome; the Client does **not** assume that
the first request must return a Task. For a Task, the probe calls `get_task`
and `list_tasks` when a context ID is available. There is no implicit
polling or automatic retry.

## Security limits

- **No direct localhost/private-IP connection** from the real published
  Client. `http://127.0.0.1:3000` is intentionally rejected.
- No injected resolver, fake CA, TLS disable, proxy workaround, anonymous
  public production endpoint, or cross-origin token forwarding.
- Logs/printed summaries contain no request Part text, body or credentials.
  Keep all tokens out of Git, CI, errors and telemetry.
- Ambiguous SendMessage timeout `may_have_executed = true` must **not** be
  auto-retried. Reconcile remote state according to your app's policy.
- CI currently proves **Client app behavior using fakes**, not real remote
  HTTPS exchange. See the parent Gem's native HTTPS interoperability tests.
- Server Echo demo currently binds localhost and refuses production mode; it
  cannot be reached by the real public-IP-only Client without a separate,
  explicitly approved isolated test harness or verified public HTTPS endpoint.

## Delivery status

- [x] Standalone Rails Client-only app and RC1 public API example
- [x] Unit tests and GitHub Actions workflow defined
- [x] [GitHub Actions CI PASS](https://github.com/cuichangquan/a2a-rails-client-demo/actions/runs/38047415734) — installed public RC1 Gem, offline Client tests, routes and production-start guard
- [ ] Independent Rails Server A2A v1.0 end-to-end HTTPS evidence
- [ ] Parent Gem README cross-link and Step 30 final assessment

The next milestone is an approved, independent HTTPS Server fixture and
recorded end-to-end results, without changing production security rules.

## License

MIT — see [LICENSE](LICENSE).
