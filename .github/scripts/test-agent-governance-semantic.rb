#!/usr/bin/env ruby
# Deterministic, offline fixtures for the semantic governance contract.
require "json"
require "fileutils"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class GovernanceSemanticTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  VALIDATOR = File.join(ROOT, ".github/scripts/validate-agent-governance.rb")
  MANIFEST = "agent-governance/manifest.json"
  PROFILE = "agent-governance/profiles/dotnet-library/profile.yml"

  def setup
    @scratch = Dir.mktmpdir("governance-semantic-")
    @manifest = JSON.parse(File.read(File.join(ROOT, MANIFEST)))
    paths = [MANIFEST, "agent-governance/VERSION", PROFILE,
             "agent-governance/profiles/dotnet-library/AGENTS.md"]
    paths.concat(@manifest.fetch("skills").map { |entry| entry.fetch("source") })
    paths.each do |path|
      target = File.join(@scratch, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(ROOT, path), target)
    end
  end

  def teardown
    FileUtils.remove_entry(@scratch) if @scratch && File.exist?(@scratch)
  end

  def file(path)
    File.join(@scratch, path)
  end

  def change_manifest
    yield @manifest
    File.write(file(MANIFEST), JSON.pretty_generate(@manifest) + "\n")
  end

  def change_file(path)
    File.write(file(path), yield(File.read(file(path))))
  end

  def run_validator
    Open3.capture3(RbConfig.ruby, VALIDATOR, chdir: @scratch)
  end

  def assert_valid
    output, errors, status = run_validator
    assert status.success?, "#{output}\n#{errors}"
  end

  def assert_invalid(message)
    output, errors, status = run_validator
    refute status.success?, "Invalid fixture unexpectedly passed: #{output}"
    assert_includes errors, message
  end

  def first_skill
    @manifest.fetch("skills").first.fetch("source")
  end

  def test_canonical_catalog_passes
    assert_valid
  end

  def test_quoted_yaml_name_and_folded_description_pass
    name = @manifest.fetch("skills").first.fetch("name")
    change_file(first_skill) do |value|
      value.sub(/^name: .+$/, "name: '#{name}'")
           .sub(/^description: .+$/, "description: >\n  An instruction with a colon: accepted by YAML.")
    end
    assert_valid
  end

  def test_reworded_non_contractual_profile_prose_passes
    path = "agent-governance/profiles/dotnet-library/AGENTS.md"
    change_file(path) { |value| value.gsub("## Gerenciamento de contexto", "## Contexto de trabalho") }
    assert_valid
  end

  def test_semantically_equivalent_profile_yaml_passes
    change_file(PROFILE) do |value|
      value.sub("profile: dotnet-library", 'profile: "dotnet-library"')
           .sub("manifest: ../../manifest.json", "manifest: '../../manifest.json'")
    end
    assert_valid
  end

  def test_missing_frontmatter_fails
    change_file(first_skill) { |value| value.sub(/\A---\s*\n/, "") }
    assert_invalid("YAML frontmatter must start")
  end

  def test_malformed_yaml_fails
    change_file(first_skill) { |value| value.sub(/^license: MIT$/, "license: [unterminated") }
    assert_invalid("invalid or unsafe YAML")
  end

  def test_duplicate_yaml_key_fails
    change_file(first_skill) { |value| value.sub(/^license: MIT$/, "name: conflicting\nlicense: MIT") }
    assert_invalid("duplicate YAML key")
  end

  def test_yaml_alias_fails_closed
    change_file(first_skill) { |value| value.sub(/^description: .+$/, "description: *unknown") }
    assert_invalid("invalid or unsafe YAML")
  end

  def test_name_mismatch_fails
    change_file(first_skill) { |value| value.sub(/^name: .+$/, "name: another-skill") }
    assert_invalid("declared skill name differs")
  end

  def test_empty_description_fails
    change_file(first_skill) { |value| value.sub(/^description: .+$/, "description: '  '") }
    assert_invalid("description must be a non-empty string")
  end

  def test_non_scalar_description_fails
    change_file(first_skill) { |value| value.sub(/^description: .+$/, "description: [not, text]") }
    assert_invalid("description must be a non-empty string")
  end

  def test_license_mismatch_fails
    change_file(first_skill) { |value| value.sub(/^license: MIT$/, "license: BSD") }
    assert_invalid("license must be MIT")
  end

  def test_duplicate_manifest_name_fails
    change_manifest { |catalog| catalog["skills"][1]["name"] = catalog["skills"][0]["name"] }
    assert_invalid("Duplicate skill names")
  end

  def test_duplicate_manifest_target_fails
    change_manifest { |catalog| catalog["skills"][1]["target"] = catalog["skills"][0]["target"] }
    assert_invalid("Duplicate skill targets")
  end

  def test_unsafe_source_fails
    change_manifest { |catalog| catalog["skills"][0]["source"] = "../outside/SKILL.md" }
    assert_invalid("invalid canonical source path")
  end

  def test_missing_source_fails
    FileUtils.rm(file(first_skill))
    assert_invalid("canonical source is missing")
  end

  def test_unlisted_skill_file_fails
    path = file("agent-governance/skills/dotnet/unlisted/SKILL.md")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "---\nname: unlisted\ndescription: Fixture\nlicense: MIT\n---\n")
    assert_invalid("Manifest and canonical SKILL.md files differ")
  end

  def test_invalid_distribution_policy_fails
    change_manifest { |catalog| catalog["skills"][0]["distribution"]["mode"] = "silent-overwrite" }
    assert_invalid("invalid distribution mode")
  end

  def test_invalid_upstream_owner_fails
    change_manifest { |catalog| catalog["skills"][0]["owner"]["path"] = "../other/SKILL.md" }
    assert_invalid("invalid upstream ownership path")
  end

  def test_profile_version_mismatch_fails
    change_file(PROFILE) { |value| value.sub("governance_version: 1.1.0", "governance_version: 99.0.0") }
    assert_invalid("governance_version differs from VERSION")
  end

  def test_profile_duplicate_key_fails
    change_file(PROFILE) { |value| value + "\nprofile: conflicting\n" }
    assert_invalid("duplicate YAML key")
  end

  def test_profile_manifest_reference_mismatch_fails
    change_file(PROFILE) { |value| value.sub("../../manifest.json", "../../other.json") }
    assert_invalid("manifest reference does not resolve")
  end

  def test_missing_required_command_fails
    path = "agent-governance/profiles/dotnet-library/AGENTS.md"
    change_file(path) { |value| value.gsub("dotnet restore --locked-mode", "dotnet restore") }
    assert_invalid("required deterministic command missing")
  end
end
