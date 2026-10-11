# a2a-rails-client-demo — Rails 8 A2A outbound Client

A standalone **Client-only Rails 8 application** demonstrating the released
[`a2a-rails 0.3.0`](https://rubygems.org/gems/a2a-rails/versions/0.3.0)
stable Gem. It sends A2A v1.0 Agent Card discovery and JSON-RPC requests to
a separate approved Agent, while never serving an inbound A2A endpoint.

- Gem and roadmap: https://github.com/cuichangquan/a2a-rails
- Independent [Rails Server Echo demo](https://github.com/cuichangquan/a2a-rails-demo)
  (independently upgraded to released stable 0.3.0 for Step 32)
- Historical setup: [Step 30 Issue #117](https://github.com/cuichangquan/a2a-rails/issues/117)
- Step 32: revalidate independent Client and Server against **both published stable 0.3.0** Gems.

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
- Published `a2a-rails = 0.3.0` from RubyGems, **not** Git checkout
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

The offline workflow verifies RubyGems origin and exact installed Gem version,
and selects patched `net-imap ~> 0.5.15` for the full Rails host,
with `json >= 2.19.9, < 3` checked against the installed Gem dependencies,
both missing inbound routes, Task/direct Message behavior with a stub Client,
and refusal to boot in Rails production mode. An independent **separate-process
HTTPS interoperability CI** runs against the unchanged published Server demo.

Offline tests alone do not establish real HTTPS; see the separate Step 32 evidence below.

## Step 32 — independent Rails-to-Rails real HTTPS CI

[Dedicated interop workflow](.github/workflows/interop-https.yml) runs the
**real public** `A2A::Rails::Client` API from this Client-only Rails app with the
**installed RubyGems 0.3.0** and a separate, pinned checkout of
[`a2a-rails-demo`](https://github.com/cuichangquan/a2a-rails-demo/tree/1b66a689b2cc8bd16052e9b3a8647072cfe13ec7),
using **published RubyGems 0.3.0** for the Server. It exercises the Rails
`AgentClientDemo::Probe` service, as well as the protocol API.

The Server intentionally runs development/test HTTP on `127.0.0.1:3000`,
advertising an HTTP interface. The test starts a loopback-only bridge on port
3443 with an **ephemeral self-signed TLS certificate for `echo-agent.test`**.
The bridge passes JSON-RPC requests to the real Server (no canned JSON-RPC
responses), but **rewrites only the Agent Card advertised JSONRPC interface URL**
to `https://echo-agent.test:3443/a2a`.

Because shipped SSRF policy correctly blocks loopback, the test uses a
**test-only internal policy seam** in
[`test/integration/real_https_echo.rb`](test/integration/real_https_echo.rb),
pinning the TLS socket to `127.0.0.1` with an ephemeral test CA.
This seam is not an application config, not available through the public
constructor, and never used by `app/` or `bin/probe`.
SNI / host / certificate verification and true pinned-socket TLS remain enabled.
The suite *also verifies* the normal production policy rejects loopback, and a
wrong TLS hostname fails.

Expected CI checks:

- Public Client Gem and independent Server Gem version/source identity
- Real TLS Agent Card discovery and declared JSONRPC 1.0 interface
- SendMessage completed Task, real Echo Service Artifact and GetTask
- ListTasks scoped to context, page metadata, direct Message response
- CancelTask terminal error and actual `AgentClientDemo::Probe` invocation
- Exact HTTPS origin enforcement, production loopback rejection, wrong TLS SNI/host rejection

**Scope:** a real two-process, two-Gem Rails Client↔Server exchange over
locally terminated TLS; **not** a no-injection, public-DNS/public-CA or
internet-facing production integration. No cloud, paid infrastructure, real
credentials, changes to upstream Server or weaker shipped Client security.
For such a production-shaped positive path, use separately approved and
secured public DNS + HTTPS infrastructure.

## Step 30-4 / Step 30-5 — Security checks and reproducibility

- [日本語 Quick Start（再現手順）](docs/quickstart-ja.md): test commands, CI rerun, architecture and troubleshooting.
- [Security verification matrix](docs/security-evidence.md): explicit application-level checks and remaining limitations.
- [Manual independent TLS workflow](https://github.com/cuichangquan/a2a-rails-client-demo/actions/workflows/interop-https.yml): maintainers may rerun with **Run workflow**.

The published Client demo now requires **both** a credential and its exact,
allowlisted `*_CREDENTIAL_ORIGIN` for Card or RPC authentication.
The offline tests reject incomplete audiences, unapproved hosts,
mixed public/private DNS, local or metadata IPs; they check safe error
text and ensure ambiguous Send/Cancel timeouts are never automatically retried.
Tests use deterministic internal fixtures only; they do not weaken the Gem's
production defaults.

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
- No test resolver/CA is exposed through application or production configuration.
  The CI-only TLS harness uses an isolated ephemeral test CA and internal
  loopback socket override; TLS peer validation remains enabled. No proxy
  workaround, anonymous public production endpoint or cross-origin token forwarding.
- Logs/printed summaries contain no request Part text, body or credentials.
  Keep all tokens out of Git, CI, errors and telemetry.
- Ambiguous SendMessage timeout `may_have_executed = true` must **not** be
  auto-retried. Reconcile remote state according to your app's policy.
- Offline CI checks Client behavior using fakes. Dedicated interoperability CI
  additionally tests the **real installed Client and Server Gems** over an
  isolated local TLS bridge, subject to the scope above.
- Server Echo demo binds localhost and refuses production mode; it
  cannot be reached by the real public-IP-only Client without a separate,
  explicitly approved isolated test harness or verified public HTTPS endpoint.

## Delivery status

- [x] Standalone Rails Client-only app and stable 0.3.0 public API example
- [x] Unit tests and GitHub Actions workflow defined
- [x] Published stable 0.3.0 Client-only Rails app; offline CI checks, routes and production-start guard
- [x] [Historical Step 30 isolated TLS E2E PASS](https://github.com/cuichangquan/a2a-rails-client-demo/actions/runs/38048146899) — RC1 Client + stable 0.2.0 Server (historical evidence, not Step 32 proof)
- [ ] Step 32 stable 0.3.0 ↔ stable 0.3.0 isolated real TLS E2E CI (check this repo's latest Actions run)
- [x] [Parent Gem README cross-link](https://github.com/cuichangquan/a2a-rails/pull/118) merged
- [x] Step 30-4 security regression tests and Step 30-5 reproducibility documentation (reused for Step 32; verify new CI run)
- [ ] Optional future public-DNS/public-CA direct Client positive-path proof (separate authorization and scope)

The next milestone after passing the isolated Rails-to-Rails HTTPS harness is
separately approved, public-DNS + public-CA positive-path evidence, without
changing production security rules.

## License

MIT — see [LICENSE](LICENSE).
