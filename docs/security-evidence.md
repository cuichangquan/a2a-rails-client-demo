# Published Echo baseline and structured-report candidate verification

This demo checks integration safety for the **published** a2a-rails stable 0.3.0.
It is not a production deployment review.

The 0.4.0 report candidate uses a separate, exact Git revision in
`Gemfile.candidate`. Its added normal functional checks are
`report_probe_test.rb` (Data send/result reading and invalid month) and the
candidate branch of `integration/real_https_echo.rb` (real report, GetTask Data
history/Artifact, and business rejection). The existing bridge and protection
checks below are unchanged. Run reports must distinguish candidate SHA evidence
from historical published 0.3.0 evidence; see [candidate instructions](report-candidate.md).

| Scenario | Test |
| --- | --- |
| HTTPS and exact origin only | client_security_test.rb |
| Card and RPC credentials bound independently | client_security_test.rb |
| Invalid configuration produces safe error text | client_security_test.rb |
| Blocked local, metadata and mixed DNS answers | client_security_test.rb |
| Ambiguous Send/Cancel timeouts are not retried | client_security_test.rb |
| TLS hostname mismatch and pinned network socket | integration/real_https_echo.rb |
| Independent Rails 8 Server actual Task/Message | integration/real_https_echo.rb |
| Client-only routes absent | client_only_routes_test.rb |
| Public RubyGems dependency identity (`0.3.0`) and host dependency bounds (`json`, `net-imap`) | GitHub Actions workflows |

The full integration test uses an isolated loopback TLS bridge and a
temporary certificate. It is not a public DNS/public CA connection test.

Remaining production controls: authentication, authorization, logging
outside this demo, durable storage, rate limiting and deployment review.
See https://github.com/cuichangquan/a2a-rails/issues/11.

Reproduce tests using [Japanese Quick Start](quickstart-ja.md).
