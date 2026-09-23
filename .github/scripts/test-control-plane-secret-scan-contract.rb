#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

class SecretScanContractError < StandardError; end

def assert(condition, message)
  raise SecretScanContractError, message unless condition
end

def load_workflow(path)
  YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::SyntaxError => e
  raise SecretScanContractError, "#{path}: invalid YAML: #{e.message.lines.first.to_s.strip}"
end

def workflow_events(document)
  # Psych follows YAML 1.1 and may deserialize the unquoted "on" key as true.
  document["on"] || document[true] || {}
end

caller_path = ".github/workflows/control-plane-secret-scan.yml"
reusable_path = ".github/workflows/reusable-secret-scan.yml"

[caller_path, reusable_path].each do |path|
  assert(File.file?(path) && !File.zero?(path), "#{path}: workflow is missing or empty.")
end

caller = load_workflow(caller_path)
assert(caller.is_a?(Hash), "#{caller_path}: top-level document must be a mapping.")

events = workflow_events(caller)
assert(events.is_a?(Hash), "#{caller_path}: on must be a mapping.")
%w[pull_request push schedule workflow_dispatch].each do |event|
  assert(events.key?(event), "#{caller_path}: missing required #{event} trigger.")
end
assert(!events.key?("pull_request_target"), "#{caller_path}: pull_request_target is forbidden.")

pull_request = events["pull_request"]
if pull_request.is_a?(Hash)
  forbidden_filters = %w[paths paths-ignore branches branches-ignore types] & pull_request.keys
  assert(forbidden_filters.empty?,
         "#{caller_path}: pull_request must not use filters that can suppress the required check: #{forbidden_filters.join(', ')}.")
end

push = events["push"]
assert(push.is_a?(Hash), "#{caller_path}: push trigger must define branches.")
branches = push["branches"]
assert(branches.is_a?(Array) && branches.include?("main"),
       "#{caller_path}: push trigger must include main.")

schedule = events["schedule"]
assert(schedule.is_a?(Array) && !schedule.empty?, "#{caller_path}: schedule must contain at least one cron entry.")
assert(schedule.all? { |entry| entry.is_a?(Hash) && entry["cron"].is_a?(String) && !entry["cron"].strip.empty? },
       "#{caller_path}: every schedule entry must define a cron expression.")

permissions = caller["permissions"]
assert(permissions == { "contents" => "read" },
       "#{caller_path}: top-level permissions must be exactly contents: read.")

jobs = caller["jobs"]
assert(jobs.is_a?(Hash) && jobs.keys == ["secret-scan"],
       "#{caller_path}: caller must remain a single-purpose secret-scan job.")
job = jobs["secret-scan"]
assert(job.is_a?(Hash), "#{caller_path}: secret-scan job must be a mapping.")
assert(job["name"] == "Protect control plane",
       "#{caller_path}: required-check job name must remain 'Protect control plane'.")
assert(job["permissions"] == { "contents" => "read" },
       "#{caller_path}: job permissions must be exactly contents: read.")
assert(!job.key?("secrets"), "#{caller_path}: caller must not inherit or forward repository secrets.")
assert(!job.key?("if"),
       "#{caller_path}: secret-scan job must not be conditional; a skipped job can satisfy a required check without scanning.")

uses = job["uses"]
expected_prefix = "rodri-oliveira-dev/.github/.github/workflows/reusable-secret-scan.yml@"
assert(uses.is_a?(String) && uses.start_with?(expected_prefix),
       "#{caller_path}: caller must reference the central reusable secret scan.")
revision = uses.delete_prefix(expected_prefix)
assert(revision.match?(/\A[0-9a-f]{40}\z/),
       "#{caller_path}: reusable workflow reference must be a full immutable 40-character commit SHA.")

reusable = load_workflow(reusable_path)
assert(reusable.is_a?(Hash), "#{reusable_path}: top-level document must be a mapping.")
reusable_events = workflow_events(reusable)
assert(reusable_events.is_a?(Hash) && reusable_events.key?("workflow_call"),
       "#{reusable_path}: reusable scanner must expose workflow_call.")
assert(!reusable_events.key?("pull_request_target"),
       "#{reusable_path}: pull_request_target is forbidden.")
assert(reusable["permissions"] == { "contents" => "read" },
       "#{reusable_path}: reusable workflow permissions must be exactly contents: read.")

scanner_job = reusable.dig("jobs", "secret-scan")
assert(scanner_job.is_a?(Hash), "#{reusable_path}: secret-scan job is missing.")
assert(scanner_job["name"] == "Scan Git history for secrets",
       "#{reusable_path}: scanner job name changed unexpectedly.")
assert(scanner_job["timeout-minutes"].is_a?(Integer) && scanner_job["timeout-minutes"] <= 15,
       "#{reusable_path}: scanner job must keep an explicit timeout of at most 15 minutes.")
assert(!scanner_job.key?("if"),
       "#{reusable_path}: scanner job must not be conditional; a skipped job can satisfy a required check without scanning.")
assert(!scanner_job.key?("continue-on-error"),
       "#{reusable_path}: scanner job must not allow failures to continue.")

steps = scanner_job["steps"]
assert(steps.is_a?(Array) && !steps.empty?, "#{reusable_path}: scanner steps are missing.")
enforce = steps.find { |step| step.is_a?(Hash) && step["id"] == "enforce" }
assert(enforce, "#{reusable_path}: fail-closed enforcement step is missing.")
assert(enforce["if"] == "always()", "#{reusable_path}: enforcement step must run with always().")
assert(!enforce.key?("continue-on-error"),
       "#{reusable_path}: enforcement step must not allow failures to continue.")

run = enforce["run"].to_s

classification_fallback = run.match?(/else\s*\n\s*result="tool-failure"\s*\n\s*fi/)
assert(classification_fallback,
       "#{reusable_path}: missing or unknown scan results must map to tool-failure before enforcement.")

case_match = run.match(/case\s+"\$result"\s+in\s*\n(?<body>.*?)^\s*esac\s*$/m)
assert(case_match, "#{reusable_path}: enforcement must contain a case on $result.")

arms = {}
case_match[:body].scan(/^\s*([A-Za-z0-9_*-]+)\)\s*\n(.*?)^\s*;;\s*$/m) do |label, commands|
  exit_codes = commands.scan(/^\s*exit\s+(\d+)\s*$/).flatten
  arms[label] = exit_codes
end

{
  "clean" => ["0"],
  "findings" => ["1"],
  "coverage-failure" => ["3"],
  "*" => ["2"]
}.each do |label, expected_codes|
  assert(arms[label] == expected_codes,
         "#{reusable_path}: enforcement case '#{label})' must exit exactly #{expected_codes.join(', ')}, found #{arms[label].inspect}.")
end

puts "Control-plane secret-scan caller is unconditional, least-privilege, SHA-pinned, and fail-closed."
