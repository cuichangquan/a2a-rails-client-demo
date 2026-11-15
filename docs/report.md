# Structured report example: published 0.4.0

Both Client and Server install `a2a-rails = 0.4.0` from RubyGems.
CI checks source, exact version and SHA256 of the installed package:
`77b36d4c1cc0db5ab028a35556f1495596f930a25922ff2bf29cde761d45132a`.
The separate Server checkout is pinned to reviewed commit `5f6d3bfb76c174484ac5b03eac8cfe72038ee3be`.
CI checks out that exact commit, not a moving branch. This pin identifies the
verified Server source even if main is later squash-merged with an equal tree.
Earlier fixed-Git candidate evidence is historical and does not substitute for
these published-package checks.

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

Before PR #4 is merged, run `git switch feat/structured-report-candidate` after cloning. After merge, use main.

```sh
git clone https://github.com/cuichangquan/a2a-rails-client-demo.git
cd a2a-rails-client-demo
bundle install
RAILS_ENV=test bundle exec rake test
```

Offline fakes test the Client service, not real network interoperability.

For an **approved independent HTTPS Server** running this report Skill, use the
same URL, origin and optional origin-scoped credential configuration as
`bin/probe`:

```sh
bundle exec ruby bin/report
bundle exec ruby bin/report --invalid-month
```

Expected: `TASK_STATE_COMPLETED` with the six fields above, then
`TASK_STATE_REJECTED` with no `report` field. Echo remains available through
`bin/probe`. The application Client still refuses direct localhost/private-IP
connections. Do not disable HTTPS, hostname verification or the destination
policy to make these commands reach the local HTTP Server.

## Existing isolated TLS integration harness

The existing `test/support/https_bridge.py` and
`test/integration/real_https_echo.rb` can be run in a developer test environment
as well as CI. Install the Server in its own checkout and terminal:

```sh
git clone https://github.com/cuichangquan/a2a-rails-demo.git
cd a2a-rails-demo
git fetch origin 5f6d3bfb76c174484ac5b03eac8cfe72038ee3be
git checkout --detach 5f6d3bfb76c174484ac5b03eac8cfe72038ee3be
bundle install
RAILS_ENV=test bundle exec rails server -b 127.0.0.1 -p 3000
```

From the Client checkout, use Python 3, OpenSSL and curl for the existing bridge:

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
export BUNDLE_GEMFILE="$PWD/Gemfile"
export RAILS_ENV=test
export STEP30_TEST_ONLY_TLS=1
export STEP30_TLS_CA="$tls_dir/test.crt"
bundle exec ruby test/integration/real_https_echo.rb
cleanup
trap - EXIT
```

The test requires RubyGems source and version 0.4.0 and always checks report,
GetTask Data history/Artifact and invalid month alongside Echo/Task/direct
Message. CI additionally verifies package bytes in both applications.
Stop the Server with Ctrl-C after the run. The certificate/bridge cleanup runs
on shell exit. There is no general-purpose localhost connection mode.

The bridge rewrites only the Agent Card's advertised interface URL. The existing
test-only loopback transport verifies TLS peer and hostname and remains outside
application code. Published destination protections are unchanged. This proves
local two-process TLS behavior, not public-DNS/public-CA production readiness.

The existing offline and TLS workflows now each test published 0.4.0 with an
eight-minute ceiling per job. Historical 0.3.0 and Git candidate CI runs remain
historical evidence; consult this PR's exact-commit CI for the public package.

## Supported boundary

Data input is a top-level JSON object. Omitted mediaType defaults to
`application/json`; an explicit Data mediaType must be `application/json`.
Mixed text/Data Parts in one Message are not supported in this example.
Echo remains text-only. New input restrictions do not remove existing Hash/Array
Data outputs. Formal AP2 extension negotiation, File input, SSE, Task resumption,
new retry/polling APIs and production hosting are outside this change.

Published-package verification records exact Client and Server commits and
results. This does not certify public-DNS/public-CA production readiness.

## Published-package validation record

On 2026-11-15, Linux x86_64 / Ruby 3.4.12 / Rails 8.1.4 loaded the downloaded
RubyGems 0.4.0 package with the SHA256 above in both independent applications.
Client tests: **14 runs / 80 assertions**, no failures/errors/skips. The Client
production-boot guard passed. The real separate-process TLS suite passed all
**25 checks**, including report conditions/result/history, invalid month,
Echo/Task/direct Message/ListTasks/CancelTask and the existing TLS boundaries.
The Server source is the exact commit pinned above. GitHub Actions uses Ruby
3.4.10; its exact-commit result is separate from this local record.
