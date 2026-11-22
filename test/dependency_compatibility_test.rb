# frozen_string_literal: true
require "minitest/autorun"
require "a2a-rails"
require "json_schemer"

class DependencyCompatibilityTest < Minitest::Test
  def test_published_gem_and_ecma_pattern_schema_load_together
    assert_equal "0.5.1", A2A::Rails::VERSION
    schema = JSONSchemer.schema({ "type" => "string", "pattern" => "^[A-Z]+$" }, regexp_resolver: "ecma")
    assert schema.valid?("DEMO")
    refute schema.valid?("123")
  end
end
