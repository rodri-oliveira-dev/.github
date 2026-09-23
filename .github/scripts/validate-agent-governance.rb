#!/usr/bin/env ruby
# Semantic, fail-closed contract validation. Ruby/Psych standard library only.
require "json"
require "pathname"
require "psych"

class GovernanceError < StandardError; end

def check(value, message)
  raise GovernanceError, message unless value
end

def unique!(values, label)
  check(values.uniq.length == values.length, "Duplicate #{label} in canonical manifest.")
end

def reject_duplicate_keys!(node, path)
  if node.is_a?(Psych::Nodes::Mapping)
    seen = {}
    node.children.each_slice(2) do |key, value|
      check(key.is_a?(Psych::Nodes::Scalar), "#{path}: mapping key must be scalar.")
      check(!seen.key?(key.value), "#{path}: duplicate YAML key '#{key.value}'.")
      seen[key.value] = true
      reject_duplicate_keys!(value, path)
    end
  elsif node.respond_to?(:children)
    Array(node.children).each { |child| reject_duplicate_keys!(child, path) }
  end
end

def yaml_mapping(text, path)
  document = Psych.parse(text, filename: path)
  check(document && document.root.is_a?(Psych::Nodes::Mapping),
        "#{path}: expected a YAML mapping.")
  reject_duplicate_keys!(document.root, path)
  data = Psych.safe_load(text, permitted_classes: [], permitted_symbols: [],
                        aliases: false, filename: path)
  check(data.is_a?(Hash) && data.keys.all? { |key| key.is_a?(String) },
        "#{path}: expected a mapping with string keys.")
  data
rescue Psych::Exception => error
  raise GovernanceError, "#{path}: invalid or unsafe YAML (#{error.message.lines.first.strip})."
end

def nonempty(value, label)
  check(value.is_a?(String) && !value.strip.empty?, "#{label} must be a non-empty string.")
  value
end

def policy!(entry, label, expected)
  value = entry["distribution"]
  check(value.is_a?(Hash) && value.keys.sort == %w[auto_merge local_authority mode],
        "#{label}: distribution policy must declare mode, auto_merge and local_authority.")
  check(value["mode"] == expected, "#{label}: invalid distribution mode (expected #{expected}).")
  check(value["auto_merge"] == false, "#{label}: auto_merge must be false.")
  check(value["local_authority"] == true, "#{label}: local_authority must be true.")
end

def validate!(manifest_path, version_path)
  check(File.file?(manifest_path) && File.file?(version_path),
        "Canonical manifest or VERSION is missing.")
  manifest = JSON.parse(File.read(manifest_path))
  check(manifest.is_a?(Hash) && manifest["schema_version"] == 1,
        "Unsupported manifest schema_version.")
  version = File.read(version_path).strip
  check(version.match?(/\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/),
        "VERSION must be strict MAJOR.MINOR.PATCH.")
  check(manifest["governance_version"] == version,
        "Manifest governance_version differs from VERSION.")
  profiles, skills = manifest.values_at("profiles", "skills")
  check(profiles.is_a?(Array) && profiles.length == 1, "Expected one declared profile.")
  check(skills.is_a?(Array) && !skills.empty?, "Manifest must declare at least one skill.")
  profile_entry = profiles.first
  check(profile_entry.is_a?(Hash) && profile_entry["name"] == "dotnet-library",
        "Invalid canonical profile identity.")
  profile_source = "agent-governance/profiles/dotnet-library/AGENTS.md"
  check(profile_entry["source"] == profile_source && profile_entry["target"] == "AGENTS.md",
        "Profile source/target does not match canonical path.")
  check(profile_entry["owner"] == { "type" => "central" }, "Profile ownership must be central.")
  policy!(profile_entry, "Profile", "manual")

  %w[name source target].each do |field|
    unique!(skills.map { |entry| entry.is_a?(Hash) ? entry[field] : nil }, "skill #{field}s")
  end
  sources = []
  skills.each do |skill|
    check(skill.is_a?(Hash), "Skill entries must be objects.")
    name = nonempty(skill["name"], "Skill name")
    check(name.match?(/\A[a-z0-9][a-z0-9-]*\z/), "Invalid skill name '#{name}'.")
    check(skill["profile"] == profile_entry["name"], "#{name}: unknown profile.")
    source = nonempty(skill["source"], "#{name} source")
    match = source.match(%r{\Aagent-governance/skills/(?:dotnet|dotnet-library)/([a-z0-9-]+)/SKILL\.md\z})
    check(match && match[1] == name, "#{name}: invalid canonical source path.")
    check(skill["target"] == ".agents/skills/#{name}/SKILL.md",
          "#{name}: invalid consumer target path.")
    owner = skill["owner"]
    check(owner.is_a?(Hash), "#{name}: invalid owner.")
    case owner["type"]
    when "upstream"
      check(owner.keys.sort == %w[path repository type] &&
            owner["repository"] == "rodri-oliveira-dev/dotnet-library-template" &&
            owner["path"] == skill["target"], "#{name}: invalid upstream ownership path.")
      policy!(skill, name, "pull-request-existing")
    when "central"
      check(owner == { "type" => "central" }, "#{name}: invalid central ownership.")
      policy!(skill, name, "manual")
    else
      raise GovernanceError, "#{name}: unsupported owner type."
    end

    check(File.file?(source) && !File.symlink?(source),
          "#{name}: canonical source is missing or a symlink: #{source}.")
    lines = File.readlines(source, encoding: "UTF-8")
    check(lines.first&.strip == "---", "#{source}: YAML frontmatter must start with ---.")
    closing = (1...lines.length).find { |index| lines[index].strip == "---" }
    check(closing, "#{source}: YAML frontmatter closing delimiter missing.")
    metadata = yaml_mapping(lines[1...closing].join, source)
    check(metadata["name"] == name, "#{source}: declared skill name differs from manifest '#{name}'.")
    nonempty(metadata["description"], "#{source} description")
    check(metadata["license"] == "MIT", "#{source}: license must be MIT.")
    sources << source
  end
  check(Dir.glob("agent-governance/skills/**/SKILL.md").sort == sources.sort,
        "Manifest and canonical SKILL.md files differ.")

  profile_path = "agent-governance/profiles/dotnet-library/profile.yml"
  check(File.file?(profile_path) && !File.symlink?(profile_path),
        "Canonical profile.yml is missing or a symlink.")
  profile = yaml_mapping(File.read(profile_path), profile_path)
  check(profile["schema_version"] == 1, "#{profile_path}: invalid schema_version.")
  check(profile["profile"] == profile_entry["name"], "#{profile_path}: profile identity mismatch.")
  check(profile["governance_version"] == version, "#{profile_path}: governance_version differs from VERSION.")
  check(profile["status"] == "active", "#{profile_path}: profile status must be active.")
  reference = nonempty(profile["manifest"], "#{profile_path} manifest reference")
  check(!Pathname.new(reference).absolute? &&
        File.expand_path(reference, File.dirname(profile_path)) == File.expand_path(manifest_path),
        "#{profile_path}: manifest reference does not resolve to canonical catalog.")

  agents = File.read(profile_source)
  ["dotnet restore --locked-mode",
   "dotnet build --configuration Release --no-restore",
   "dotnet test --configuration Release --no-build"].each do |command|
    check(agents.each_line.any? { |line| line.strip == command },
          "#{profile_source}: required deterministic command missing: #{command}.")
  end
end

begin
  validate!(ARGV.fetch(0, "agent-governance/manifest.json"),
            ARGV.fetch(1, "agent-governance/VERSION"))
  puts "Semantic agent-governance catalog, YAML metadata and profile validation passed."
rescue GovernanceError, JSON::ParserError, ArgumentError, SystemCallError, EncodingError => error
  warn "::error title=Invalid agent governance contract::#{error.message.gsub(/[\r\n]/, " ")}"
  exit 1
end
