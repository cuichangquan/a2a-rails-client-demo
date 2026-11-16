# Structured report and continuation: unpublished 0.5.0 candidate

Both hosts use Rails 8.1.4.1 and the exact Git Gem revision/version recorded in
`candidate.json`. No unpublished version is fetched from RubyGems. The TLS
workflow also pins the independent Server checkout with its full `SERVER_REF`.
`bin/verify_candidate` rejects any different Gem revision/version/source.

## Read the question and answer

```ruby
result = client.send_message(message: {
  message_id: SecureRandom.uuid, role: "ROLE_USER",
  parts: [{ data: { "year" => 2026, "month" => 10 } }]
})
task = result.task
raise "Expected a question" unless task.dig(:status, :state) == "TASK_STATE_INPUT_REQUIRED"
question = task.dig(:status, :message, :parts)
task_id = task.fetch(:id)
# GetTask can omit response history without erasing saved input:
waiting = client.get_task(id: task_id, history_length: 0)
answer = client.send_message(message: {
  message_id: SecureRandom.uuid, role: "ROLE_USER", task_id: task_id,
  parts: [{ data: { "department_id" => 123 } }]
})
raise "Task changed" unless answer.task.fetch(:id) == task_id
final = client.get_task(id: task_id, history_length: 0)
```

The question contains fixed text `Please provide: department_id.` and Data
`{"missing_fields":["department_id"]}`. The final state is `TASK_STATE_COMPLETED`,
with Data Artifact:

```json
{"year":2026,"month":10,"department_id":123,"sales_count":3,"total_amount":35000,"currency":"JPY"}
```

Protocol DTO fields use symbols; arbitrary Data keys remain strings. `task_id`
alone reuses the saved context. The Gem returns to the original report Skill;
the Server application combines only allowed user criteria from its history,
not the agent question. Later valid input can explicitly replace earlier fields.
Missing fields trigger questions; supplied invalid month 13 still rejects the
business Task and produces no report. No arbitrary JSON merging occurs in the Gem.

The same `message:, context:` Handler contract is used. A Gem-owned
`A2A::Rails::InputRequired.new(text, data: ...)` marks a question; ordinary Hash
results remain business data. SDK types are not exposed to either demo Handler
or Client service. The Task ID spans the conversation; core execution-turn IDs
prevent an old Job from finishing a newer turn. This synchronous demo has no
Job queue and does not itself validate distributed-worker guarantees.

## Commands and scenarios

After configuring an explicitly authorized independent HTTPS Agent as described
in the README:

```sh
bundle exec ruby bin/probe                    # minimal Echo/direct Message
bundle exec ruby bin/report                   # complete criteria, one-shot
bundle exec ruby bin/report --invalid-month   # month 13, no retry
bundle exec ruby bin/continue_report          # one question and answer
bundle exec ruby bin/continue_report --reask  # year -> month -> department
bundle exec ruby bin/continue_report --cancel # cancel a waiting Task
bundle exec ruby bin/continue_report --after-completion # new answer is refused
```

`ContinuationProbe` sends a bounded set of explicit messages; no polling,
workflow framework or retries. It fetches the waiting Task and final result and
checks the same Task/context. It only prints validated fixed question fields and
the synthetic report. It never prints raw errors, credentials or arbitrary Parts.
A new message after completion/cancellation returns UnsupportedOperation (-32004); this is additionally
asserted by real TLS CI. The generic Client API remains unchanged.

A response may be lost after the server executed. Do not blindly resend using a
new message ID. Inspect Task state and use the Gem's documented duplicate-ID
contract. The demo does not promise exactly-once effects, automatic recovery or
perfect detection of an old answer sent with a fresh ID.

## Reproduce isolated real TLS

Run the [dedicated workflow](../.github/workflows/interop-https.yml) on this
candidate branch, or execute its explicit steps in disposable local test
processes. The workflow installs each host independently, verifies identical
candidate pins, starts the Server on loopback port 3000, creates a one-day
self-signed test CA/certificate, starts the existing TLS bridge on 3443, and runs:

```sh
STEP30_TEST_ONLY_TLS=1 STEP30_TLS_CA=/path/to/test.crt \
  RAILS_ENV=test bundle exec ruby test/integration/real_https_echo.rb
```

The command requires the bridge/Server already running. It is not a production
Client connection recipe. The bridge changes only the Agent Card interface URL.
The test-only internal policy pins loopback sockets; TLS CA, hostname and SNI
verification remain on. Runtime Client rejects HTTP/private destinations and
has no public test-policy configuration. CI verifies normal loopback refusal
and hostname mismatch refusal as well as Echo, one-shot Data, continuation,
re-questioning, waiting cancellation and refusal of new terminal answers.

The Server uses synchronous MemoryStore: restart loses waiting Tasks. GetTask
history_length: 0 only limits the response, not inputs retained before restart.
Durable restart, PostgreSQL races and real worker tests are core Gem gates, not
claims established by this demo. No public-DNS/public-CA production integration
or full A2A conformance certification is claimed.

## Publication follow-up

After separate owner approval and actual Gem publication: replace exact Git
candidate pins in both hosts with the released RubyGems version, verify the
public package identity, rerun HTTP and real TLS on the exact resulting commits,
and update both English/Japanese docs. Candidate checks do not authorize merge,
release, tagging, deployment or new infrastructure.
