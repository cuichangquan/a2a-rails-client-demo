# Temporary regexp_parser compatibility pin

The demo pins `regexp_parser = 2.13.1` while retaining the exact published
`a2a-rails = 0.5.0` package and all Rails/json/net-imap checks. This is a consuming
application resolution workaround, not a core Gem or SDK patch.

## Evidence checked on 2026-11-16 UTC

- The [official RubyGems compact index](https://index.rubygems.org/info/json_schemer)
  still lists `json_schemer 2.5.0` as latest; its parser requirement is `~> 2.0`.
  No newer released schemer fix was available at inspection time.
- [regexp_parser's index](https://index.rubygems.org/info/regexp_parser) dates
  2.13.2 to 2026-11-16 21:23:38 UTC. Fresh installs selected it, while the last
  successful public-Gem Server run used 2.13.1 with schemer2.5.0.
- [Known-good Server CI](https://github.com/cuichangquan/a2a-rails-demo/actions/runs/43891313528)
  versus [later failing install](https://github.com/cuichangquan/a2a-rails-demo/actions/runs/43964767333):
  requiring the unchanged published Gem failed with `undefined method implements`
  for the ECMA syntax class after resolving parser2.13.2.
- Inspection of the published Gem source shows parser2.13.2 makes class
  `implements` private. Schemer2.5.0 tests `respond_to?(:implements)`, then
  selects an instance when false; that instance lacks the required method.
  This is a dependency API mismatch, not a Rails or continuation runtime change.
- The [upstream parser changelog](https://github.com/ammar/regexp_parser/blob/master/CHANGELOG.md)
  describes Ractor, tree/reference and quantifier fixes in 2.13.2, not an identified
  security fix. RubySec database revision `6c4efcdc4187a078c0a8a5e943ec346c4a49ab07` had no package entries for
  regexp_parser/json_schemer at inspection. This is bounded evidence, not a claim
  that either version or the complete dependency graph is vulnerability-free.

## Validation and removal

The exact pin stays inside schemer's declared range. `bin/verify_release` verifies
2.13.1 in addition to unchanged public Gem source/version/checksum and host bounds.
`test/dependency_compatibility_test.rb` loads the public Gem and validates an
ordinary ECMA pattern. Fresh CI installation, existing tests, actual HTTP and
independent TLS continuation must pass on the final PR heads. Historical passes
are not evidence for this fix; consult this PR's final CI.

Remove this temporary pin only when an upstream released combination has been
verified with a fresh unlocked install, public-package verification and all
existing HTTP/TLS tests. Recheck advisories at that time. Do not add monkey
patches, disable validation, change the public Gem bytes or broadly downgrade
other dependencies to make the load succeed.
