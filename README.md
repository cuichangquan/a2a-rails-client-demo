# a2a-rails-client-demo — Rails 8 A2A outbound Client

A standalone **Client-only Rails 8 application** demonstrating an unpublished
**a2a-rails 0.5.0 candidate**, based on released 0.4.0. The exact Git revision
and version are in [candidate.json](candidate.json), used by Gemfile and CI. It sends A2A v1.0 Agent Card discovery and JSON-RPC requests to
a separate approved Agent, while never serving an inbound A2A endpoint.

- Gem and roadmap: https://github.com/cuichangquan/a2a-rails
- Independent [Rails Server Echo demo](https://github.com/cuichangquan/a2a-rails-demo)
  (Echo and structured report)
- Historical setup: [Step 30 Issue #117](https://github.com/cuichangquan/a2a-rails/issues/117)
- Current validation target: both hosts load the identical pinned Git candidate; see exact-commit CI for results.

> **Local development/test only.** This Client host refuses production boot.
> Do not weaken published Gem SSL validation, IP pinning, SSRF policy,
> HTTP redirects, or auth-origin boundaries to connect to localhost.

## Structured report: call Rails business logic with Data

The [report walkthrough](docs/report.md) sends
`{"year":2026,"month":10,"department_id":123}` to a separate Rails Service and
reads a Data Artifact: **3 sales, JPY 35,000**. Month 13 produces a rejected
Task without a report. Echo remains available through `bin/probe`.

Both demos use the **same pinned, unpublished Git candidate**, not a presumed
RubyGems 0.5.0 release. Install once with `bundle install`; verify with
`bundle exec ruby bin/verify_candidate`. Run offline tests with
`RAILS_ENV=test bundle exec rake test`.

With an authorized independent HTTPS report Agent configured:

```sh
bundle exec ruby bin/report                 # all criteria, one call
bundle exec ruby bin/report --invalid-month # existing rejection
bundle exec ruby bin/continue_report        # ask department, answer, same Task
bundle exec ruby bin/continue_report --reask # two questions, same Task
bundle exec ruby bin/continue_report --cancel # cancel while waiting
bundle exec ruby bin/continue_report --after-completion # new answer is refused
```

The bounded continuation example reads the question through status.message,
fetches the waiting Task with history_length: 0, sends an explicit answer using
only task_id, and verifies that the same Task/context completes with 3 sales /
JPY 35,000. It prints only validated synthetic question/report fields. No generic
polling/retry API or automatic resend is added. Restarting the synchronous
MemoryStore Server loses waiting Tasks. See [the walkthrough](docs/report.md).

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

- Ruby **3.4.10**, Rails **8.1.4.1**, Bundler
- Exact unpublished Git candidate from `candidate.json` (installed by Bundler)
- For real remote checks, an approved A2A v1.0 JSON-RPC Agent reachable on a
  **public-destination IP, public-DNS hostname, valid CA-issued HTTPS certificate**
- No external AI provider, database, Redis, Docker, or GCP required for offline tests

## Quick Start — run offline tests

```bash
git clone https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
git switch feat/task-continuation-demo # until candidate PR is merged
bundle install
RAILS_ENV=test bundle exec rake test
```

The offline workflow verifies exact Git revision and installed candidate version,
and selects patched `net-imap ~> 0.5.15` for the full Rails host,
with `json >= 2.19.9, < 3` checked against the installed Gem dependencies,
both missing inbound routes, Task/direct Message behavior with a stub Client,
and refusal to boot in Rails production mode. An independent **separate-process
HTTPS interoperability CI** runs against the separately pinned candidate Server demo.

Offline tests alone do not establish real HTTPS; see the dedicated interop checks below.

## Independent Rails-to-Rails real HTTPS candidate CI

[Dedicated interop workflow](.github/workflows/interop-https.yml) runs the real
public Client API with a separate Server checkout pinned by `SERVER_REF` in that
workflow. Each host independently resolves its Gemfile. CI verifies both exact
Git candidate identities and identical `candidate.json` files. This is candidate
source verification, not public RubyGems package identity.

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
- Report Data, JPY 35,000 aggregate, original GetTask history and invalid-month rejection
- Question/answer on the same Task, two questions, waiting cancellation and terminal-answer refusal
- Exact HTTPS origin enforcement, production loopback rejection, wrong TLS SNI/host rejection

**Scope:** a real two-process, two-Gem Rails Client↔Server exchange over
locally terminated TLS; **not** a no-injection, public-DNS/public-CA or
internet-facing production integration. No cloud, paid infrastructure, real
credentials or weaker shipped Client security.
For such a production-shaped positive path, use separately approved and
secured public DNS + HTTPS infrastructure.

## Step 30-4 / Step 30-5 — Security checks and reproducibility

- [日本語 Quick Start（再現手順）](docs/quickstart-ja.md): test commands, CI rerun, architecture and troubleshooting.
- [Security verification matrix](docs/security-evidence.md): explicit application-level checks and remaining limitations.
- [Manual independent TLS workflow](https://github.com/cuichangquan/a2a-rails-client-demo/actions/workflows/interop-https.yml): maintainers may rerun with **Run workflow**.

The Client demo requires **both** a credential and its exact,
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
- Echo summaries contain no request Part text, body or credentials. The report
  command intentionally prints only the six known synthetic aggregate fields,
  never arbitrary remote Parts, raw protocol bodies or credentials.
  Keep all tokens out of Git, CI, errors and telemetry.
- Ambiguous SendMessage timeout `may_have_executed = true` must **not** be
  auto-retried. Reconcile remote state according to your app's policy.
- Offline CI checks Client behavior using fakes. Dedicated interoperability CI
  additionally tests the **real installed Client and Server Gems** over an
  isolated local TLS bridge, subject to the scope above.
- Server Echo demo binds localhost and refuses production mode; it
  cannot be reached by the real public-IP-only Client without a separate,
  explicitly approved isolated test harness or verified public HTTPS endpoint.

## Delivery / release boundary

This branch implements a candidate, not a published 0.5.0 Gem. Existing Echo,
Direct Message and one-shot report stay available. See the final exact-SHA CI
and review records before calling the candidate verified. Historical 0.3.0 and
0.4.0 passes do not establish new continuation behavior.

After separately authorized formal Gem publication, replace both demo Git pins
with the public package, verify the package bytes and repeat HTTP/TLS checks.
Tagging, release, deployment and new public infrastructure are not implied.
Public-DNS/public-CA positive-path testing remains a separate optional scope.

## License

MIT — see [LICENSE](LICENSE).
