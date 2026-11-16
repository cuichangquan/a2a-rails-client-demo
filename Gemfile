# frozen_string_literal: true
source "https://rubygems.org"

ruby "~> 3.4.0"
gem "rails", "= 8.1.4.1"
gem "puma", "~> 6.6"
# Unpublished candidate: the exact Git revision is recorded once for both
# Bundler resolution and verification. Never resolve 0.5.0 from RubyGems yet.
require "json"
candidate = JSON.parse(File.read(File.join(__dir__, "candidate.json")))
gem "a2a-rails", "= #{candidate.fetch('version')}",
  git: "https://github.com/cuichangquan/a2a-rails.git", ref: candidate.fetch("revision")
# Audited patched Rails mail dependency (avoid vulnerable 0.4.25).
gem "net-imap", "~> 0.5.15"
