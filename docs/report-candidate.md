# Structured report example: unpublished 0.4.0 candidate

This example calls Rails business logic with a Data Part. It requires the fixed
Gem commit in `Gemfile.candidate` on **both** Client and Server. It does not claim
that RubyGems already contains version 0.4.0. The normal `Gemfile` remains pinned
to released 0.3.0 for the existing Echo example. Do not use that released Server
to run the new report example.

Candidate pins:
- Gem: `e13b3ef06698990c6a7b9e1522bf09f7c38e31c5`.
- Independent Server: `db100a2b05c14f0ec693918593adaa141a43cfce`.

The candidate still carries version constant 0.3.0 until release preparation.
Its **Git source revision**, rather than that constant, distinguishes it from
the published RubyGems 0.3.0 package.

## Request, service, and result

The Client sends one Part:

```ruby
client.send_message(message: {
  message_id: SecureRandom.uuid,
  role: "ROLE_USER",
  parts: [{ data: { "year" => 2026, "month" => 10, "department_id" => 123 },
            media_type: "application/json" }]
})
```

Protocol fields use the public Ruby Client's symbol names. Keys **inside** Data
remain JSON string keys. The report example does not use message metadata for
its business inputs. The Server's existing Router selects `report` for Data and
`reply` for text; report declares `input_modes: ["application/json"]`. The Gem
enforces the selected Skill's Data contract before invoking its Handler.

Server `Reports::Generate` adapts `message:, context:` to the SDK-independent
`Reports::SalesSummary` Service. The fixed synthetic rows matching October 2026,
department 123 are JPY 12,000, 18,000 and 5,000. Other months, departments and
years are excluded. The returned Data Artifact is:

```json
{"year":2026,"month":10,"department_id":123,"sales_count":3,"total_amount":35000,"currency":"JPY"}
```

Calling the Service directly inside the Server app performs only this business
calculation. A2A adds Agent Card discovery, serialization, Router/Skill selection,
Task handling, a Data Artifact and retrieval by the separate Client. Neither
path uses an LLM, external service, database or job queue. Tasks use synchronous
execution and the process-local MemoryStore.

`AgentClientDemo::ReportProbe` sends once, calls GetTask once, checks that the
report matches on retrieval and displays only the six named report fields.
It does not poll, retry, print raw remote Parts or treat every completed A2A
Task as a valid business report. A month of 13 is an invalid business condition:
the Server rejects the Task and returns no report Artifact. This is distinct
from a malformed protocol Part being rejected before Handler execution.

## Local use

Before merge, check out this candidate PR branch rather than published `main`:

```sh
git clone --branch feat/structured-report-candidate --single-branch https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
```

Install with `BUNDLE_GEMFILE=Gemfile.candidate bundle install`, then run offline
tests with `BUNDLE_GEMFILE=Gemfile.candidate RAILS_ENV=test bundle exec rake test`.
Offline fakes test the Client service, not real network interoperability.

For an **approved independent HTTPS Server** running this report Skill, use the
same URL, origin and optional origin-scoped credential configuration as
`bin/probe`:

```sh
BUNDLE_GEMFILE=Gemfile.candidate bundle exec ruby bin/report
BUNDLE_GEMFILE=Gemfile.candidate bundle exec ruby bin/report --invalid-month
```

Expected: `TASK_STATE_COMPLETED` with the six fields above, then
`TASK_STATE_REJECTED` with no `report` field. Echo remains available through
`bin/probe`. The application Client still refuses direct localhost/private-IP
connections. Do not disable HTTPS, hostname verification or the destination
policy to make these commands reach the local HTTP Server.

## Existing isolated TLS integration harness

The existing `test/support/https_bridge.py` and
`test/integration/real_https_echo.rb` can be run in a developer test environment
as well as CI. Both applications must have installed their **own** candidate
Gemfile. Check out the independent Server at the exact Server SHA above (from
its `feat/structured-report-demo` PR branch), not its published main. Run it on
`127.0.0.1:3000` with its candidate Gemfile, then use
the following local test steps from the Client checkout. These use the existing
bridge, Python 3, OpenSSL and curl, with no CI-specific environment variables:

```sh
tls_dir=$(mktemp -d)
bridge_pid=''
cleanup() {
  test -z "$bridge_pid" || kill "$bridge_pid" 2>/dev/null || true
  rm -f "$tls_dir/test.key" "$tls_dir/test.crt"
  rmdir "$tls_dir" 2>/dev/null || true
}
trap cleanup EXIT
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 1 \
  -keyout "$tls_dir/test.key" -out "$tls_dir/test.crt" \
  -subj /CN=echo-agent.test -addext subjectAltName=DNS:echo-agent.test >/dev/null 2>&1
chmod 600 "$tls_dir/test.key"
python3 test/support/https_bridge.py \
  --certificate "$tls_dir/test.crt" --key "$tls_dir/test.key" &
bridge_pid=$!
for attempt in $(seq 1 30); do
  if curl --fail --silent --noproxy '*' --cacert "$tls_dir/test.crt" \
    --resolve echo-agent.test:3443:127.0.0.1 \
    https://echo-agent.test:3443/.well-known/agent-card.json >/dev/null; then break; fi
  sleep 1
done
export BUNDLE_GEMFILE="$PWD/Gemfile.candidate"
export RAILS_ENV=test
export STEP30_TEST_ONLY_TLS=1
export STEP30_TLS_CA="$tls_dir/test.crt"
export A2A_CANDIDATE_SHA=e13b3ef06698990c6a7b9e1522bf09f7c38e31c5
bundle exec ruby test/integration/real_https_echo.rb
cleanup
trap - EXIT
```

The guard checks the exact loaded Git source revision. A candidate run adds the
report request, expected aggregate, original Data history/GetTask and invalid
month checks to the existing Echo/Task/direct Message test. The workflow also
checks the independent Server's pinned source. Stop the temporary bridge and
Server after the run (Ctrl-C in the Server terminal). The certificate/bridge
cleanup above runs on shell exit as well. There is no new general-purpose
localhost connection mode.

The bridge rewrites only the Agent Card's advertised interface URL. The existing
test-only loopback transport verifies TLS peer and hostname and remains outside
application code. Published destination protections are unchanged. This proves
local two-process TLS behavior, not public-DNS/public-CA production readiness.

The existing offline and TLS workflows each retain a published 0.3.0 job and
add a separate candidate job, with an eight-minute ceiling per job. The stable
TLS job keeps its historical pinned Echo Server, while the candidate job uses
the independent Server SHA above. A fake Client test is never presented as real
Data interoperability with the published 0.3.0 Server.

Local observations on 2026-11-15: existing Linux Ruby 3.4.12; published and
candidate Client suites each **14 tests / 80 assertions**, zero failures/errors/
skips. Server business tests: **5 / 17**. Actual HTTP Echo and report checks,
isolated TLS report/result/GetTask/invalid-month checks and existing Echo/direct
Message/TLS checks passed with the candidate. CI uses the repository's Ruby
3.4.10; consult the associated PR's exact-commit checks for that separate result.

## Candidate boundary and release follow-up

Data input is a top-level JSON object. Omitted mediaType defaults to
`application/json`; an explicit Data mediaType must be `application/json`.
Mixed text/Data Parts in one Message are not supported in this candidate.
Echo remains text-only. New input restrictions do not remove existing Hash/Array
Data outputs. Formal AP2 extension negotiation, File input, SSE, Task resumption,
new retry/polling APIs and production hosting are outside this change.

Candidate tests must record Gem and Server commit IDs and actual results.
Historical stable 0.3.0 CI links are not evidence for this candidate. After a
separate publication decision, pin both demos to the new **published** Gem,
replace candidate-source identity checks with RubyGems identity checks and run
the same offline, Server HTTP and isolated TLS suites again.
