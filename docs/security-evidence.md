# Published 0.5.0 Echo, report and continuation verification

Both applications load the same published RubyGems 0.5.0 package. Unit tests
cover Data, question interpretation and bounded answer sending. Real TLS tests
cover same-Task continuation, repeated questions, waiting cancellation and new
terminal-answer refusal, alongside existing Echo/report cases. CI verifies RubyGems
source/version/package SHA-256 and host dependency bounds. See [the walkthrough](report.md).
Historical release passes are not evidence for this published-package check. Consult the
exact-head CI/review results; a test definition alone is not a passing run.
This is not a production deployment review.

| Scenario | Test |
| --- | --- |
| HTTPS and exact origin only | client_security_test.rb |
| Card and RPC credentials bound independently | client_security_test.rb |
| Invalid configuration produces safe error text | client_security_test.rb |
| Blocked local, metadata and mixed DNS answers | client_security_test.rb |
| Ambiguous Send/Cancel timeouts are not retried | client_security_test.rb |
| TLS hostname mismatch and pinned network socket | integration/real_https_echo.rb |
| Independent Rails 8 Server actual Task/Message | integration/real_https_echo.rb |
| Same Task/context question/answer/re-question/cancel | continuation_probe_test.rb + integration/real_https_echo.rb |
| No automatic answer resend on interruption | continuation_probe_test.rb |
| Client-only routes absent | client_only_routes_test.rb |
| Public RubyGems package identity and host dependency bounds (`json`, `net-imap`) | GitHub Actions workflows |

The full integration test uses an isolated loopback TLS bridge and a
temporary certificate. It is not a public DNS/public CA connection test.

Remaining production controls: authentication, authorization, logging
outside this demo, durable storage, rate limiting and deployment review.
See https://github.com/cuichangquan/a2a-rails/issues/11.

Reproduce tests using [Japanese Quick Start](quickstart-ja.md).
