# Step 30-4 verification matrix

This demo checks integration safety for the **published** a2a-rails RC1.
It is not a production deployment review.

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
| Public RubyGems dependency identity | GitHub Actions workflows |

The full integration test uses an isolated loopback TLS bridge and a
temporary certificate. It is not a public DNS/public CA connection test.

Remaining production controls: authentication, authorization, logging
outside this demo, durable storage, rate limiting and deployment review.
See https://github.com/cuichangquan/a2a-rails/issues/11.

Reproduce tests using [Japanese Quick Start](quickstart-ja.md).
