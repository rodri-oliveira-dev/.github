#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

class CommunityHealthError < StandardError; end

def assert(condition, message)
  raise CommunityHealthError, message unless condition
end

def load_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::SyntaxError => e
  raise CommunityHealthError, "#{path}: invalid YAML: #{e.message.lines.first.to_s.strip}"
end

required_files = %w[
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md
  SECURITY.md
  SUPPORT.md
  .github/PULL_REQUEST_TEMPLATE.md
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/ISSUE_TEMPLATE/config.yml
]

required_files.each do |path|
  assert(File.file?(path) && !File.zero?(path), "#{path}: required community-health file is missing or empty.")
end

forms = {
  ".github/ISSUE_TEMPLATE/bug_report.yml" => %w[preflight problem expected reproduction environment evidence],
  ".github/ISSUE_TEMPLATE/feature_request.yml" => %w[preflight problem proposal alternatives compatibility context]
}

forms.each do |path, expected_ids|
  form = load_yaml(path)
  assert(form.is_a?(Hash), "#{path}: top-level document must be a mapping.")
  %w[name description body].each do |key|
    assert(form.key?(key), "#{path}: missing required key #{key}.")
  end
  assert(form["name"].is_a?(String) && !form["name"].strip.empty?, "#{path}: name must be non-empty.")
  assert(form["description"].is_a?(String) && !form["description"].strip.empty?,
         "#{path}: description must be non-empty.")
  assert(form["body"].is_a?(Array) && !form["body"].empty?, "#{path}: body must contain form elements.")

  ids = []
  form["body"].each_with_index do |field, index|
    assert(field.is_a?(Hash), "#{path}: body[#{index}] must be a mapping.")
    type = field["type"]
    assert(%w[markdown textarea input dropdown checkboxes].include?(type),
           "#{path}: body[#{index}] has unsupported type #{type.inspect}.")
    next if type == "markdown"

    id = field["id"]
    assert(id.is_a?(String) && id.match?(/\A[a-z][a-z0-9_-]*\z/),
           "#{path}: body[#{index}] requires a stable lowercase id.")
    ids << id
    assert(field["attributes"].is_a?(Hash), "#{path}: field #{id} requires attributes.")
  end

  assert(ids.uniq.length == ids.length, "#{path}: field ids must be unique.")
  assert(ids == expected_ids, "#{path}: expected stable field ids #{expected_ids.join(', ')}; got #{ids.join(', ')}.")
  assert(!form.key?("labels"), "#{path}: inherited defaults must not depend on labels existing in consumer repositories.")
  assert(!form.key?("assignees"), "#{path}: inherited defaults must not hard-code repository-specific assignees.")

  serialized = form.to_s.downcase
  %w[dotnet .net node.js terraform kubernetes].each do |stack|
    assert(!serialized.include?(stack), "#{path}: inherited issue form must remain stack-agnostic (found #{stack}).")
  end
end

config = load_yaml(".github/ISSUE_TEMPLATE/config.yml")
assert(config.is_a?(Hash), ".github/ISSUE_TEMPLATE/config.yml: top-level document must be a mapping.")
assert(config["blank_issues_enabled"] == false,
       ".github/ISSUE_TEMPLATE/config.yml: blank issues must stay disabled so users choose an intent-specific form.")

pr_template = File.read(".github/PULL_REQUEST_TEMPLATE.md")
[
  "## Summary / Resumo",
  "## Motivation / Motivação",
  "## Validation / Validação",
  "## Compatibility and risk / Compatibilidade e risco",
  "## Checklist"
].each do |heading|
  assert(pr_template.include?(heading), ".github/PULL_REQUEST_TEMPLATE.md: missing section #{heading}.")
end

support = File.read("SUPPORT.md")
assert(support.include?("Security is different from support"),
       "SUPPORT.md: support/security boundary is missing in English.")
assert(support.include?("Segurança é diferente de suporte"),
       "SUPPORT.md: support/security boundary is missing in Portuguese.")
assert(support.include?("Security → Report a vulnerability"),
       "SUPPORT.md: private vulnerability reporting guidance is missing.")

conduct = File.read("CODE_OF_CONDUCT.md")
assert(conduct.include?("## English") && conduct.include?("## Português"),
       "CODE_OF_CONDUCT.md: bilingual default policy is incomplete.")
assert(conduct.include?("Technical disagreement is welcome."),
       "CODE_OF_CONDUCT.md: technical disagreement boundary must remain explicit.")

puts "Community-health defaults are present, valid, bilingual where required, and stack-agnostic."
