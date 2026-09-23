#!/usr/bin/env ruby
# Fail closed when Dependabot or a manual change replaces an immutable Action pin.
# No network requests or write permissions are needed.
require "psych"
require "tmpdir"
require "fileutils"

class DependabotPolicyError < StandardError; end

def ensure_policy(condition, message)
  raise DependabotPolicyError, message unless condition
end

def validate_config(path)
  config = Psych.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
  ensure_policy(config.is_a?(Hash) && config["version"] == 2,
                "#{path}: expected Dependabot config version 2.")
  updates = config["updates"]
  ensure_policy(updates.is_a?(Array), "#{path}: updates must be an array.")
  actions = updates.select { |entry| entry.is_a?(Hash) && entry["package-ecosystem"] == "github-actions" }
  ensure_policy(actions.length == 1, "#{path}: expected exactly one github-actions entry.")
  entry = actions.fetch(0)
  ensure_policy(entry["directory"] == "/", "#{path}: github-actions directory must be '/'.")
  schedule = entry["schedule"]
  ensure_policy(schedule.is_a?(Hash) &&
                schedule["interval"] == "weekly" &&
                schedule["day"] == "tuesday" &&
                schedule["time"] == "10:00" &&
                schedule["timezone"] == "America/Sao_Paulo",
                "#{path}: expected Tuesday 10:00 America/Sao_Paulo schedule.")
  limit = entry["open-pull-requests-limit"]
  ensure_policy(limit.is_a?(Integer) && limit.between?(1, 10),
                "#{path}: open-pull-requests-limit must be between 1 and 10.")
  groups = entry["groups"]
  ensure_policy(groups.is_a?(Hash) && groups.keys == ["artifact-io"],
                "#{path}: only the narrow artifact-io update group is permitted.")
  artifact_group = groups["artifact-io"]
  ensure_policy(artifact_group.is_a?(Hash) &&
                artifact_group["applies-to"] == "version-updates" &&
                artifact_group["patterns"] == %w[actions/upload-artifact actions/download-artifact] &&
                artifact_group["update-types"] == %w[minor patch],
                "#{path}: artifact-io must group only minor/patch upload/download updates.")
end

def validate_pins(workflow_dir)
  workflows = Dir.glob(File.join(workflow_dir, "*.{yml,yaml}"))
  ensure_policy(!workflows.empty?, "#{workflow_dir}: no workflow files found.")
  checked = 0
  workflows.each do |path|
    File.foreach(path).with_index(1) do |line, line_number|
      next unless (match = line.match(/^\s*(?:-\s*)?uses:\s*["']?([^#\s"']+)/))
      reference = match[1]
      next if reference.start_with?("./")
      ensure_policy(reference.match?(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.\/-]+)?@[0-9a-f]{40}\z/),
                    "#{path}:#{line_number}: remote uses must pin a full 40-character commit SHA (got #{reference}).")
      checked += 1
    end
  end
  ensure_policy(checked.positive?, "#{workflow_dir}: expected SHA-pinned remote Actions.")
end

def run_self_tests
  Dir.mktmpdir("dependabot-actions-policy-") do |root|
    config = File.join(root, "dependabot.yml")
    workflow_dir = File.join(root, "workflows")
    FileUtils.mkdir_p(workflow_dir)
    FileUtils.cp(".github/dependabot.yml", config)
    File.write(File.join(workflow_dir, "example.yml"),
               "steps:\n  - uses: actions/checkout@#{'a' * 40} # v1\n  - uses: ./.github/actions/local\n")
    validate_config(config)
    validate_pins(workflow_dir)

    File.write(File.join(workflow_dir, "example.yml"), "steps:\n  - uses: actions/checkout@v7\n")
    begin
      validate_pins(workflow_dir)
      raise DependabotPolicyError, "Self-test accepted a mutable Action tag."
    rescue DependabotPolicyError => error
      raise unless error.message.include?("full 40-character commit SHA")
    end

    File.write(config, File.read(config).sub("interval: \"weekly\"", "interval: \"daily\""))
    begin
      validate_config(config)
      raise DependabotPolicyError, "Self-test accepted a changed schedule."
    rescue DependabotPolicyError => error
      raise if error.message == "Self-test accepted a changed schedule."
    end
  end
end

begin
  validate_config(".github/dependabot.yml")
  validate_pins(".github/workflows")
  if ARGV == ["--self-test"]
    run_self_tests
    puts "Dependabot config, immutable Action pins and negative fixtures passed."
  elsif ARGV.empty?
    puts "Dependabot config and immutable Action pins passed."
  else
    raise DependabotPolicyError, "Usage: ruby .github/scripts/test-dependabot-actions.rb [--self-test]"
  end
rescue DependabotPolicyError, Psych::Exception, SystemCallError => error
  warn "::error title=Invalid Dependabot Actions policy::#{error.message.gsub(/[\r\n]/, ' ')}"
  exit 1
end
