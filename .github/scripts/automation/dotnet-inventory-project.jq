def text_or_empty(value): value // "";

def inventory_projects($repository; $visibility; $default_branch; $exit_code):
  . as $report
  | ($report.dotNetSdk.configured.version // "") as $configured_sdk
  | ($report.dotNetSdk.resolvedVersion // "") as $repo_resolved_sdk
  | $report.projects[]?
  | ([
      .diagnostics[]?.severity,
      (if $exit_code == 0 then empty else "warning" end)
    ] | map((. // "") | ascii_downcase)) as $severities
  | {
      repository: $repository,
      visibility: $visibility,
      default_branch: $default_branch,
      project_path: text_or_empty(.path),
      project_name: text_or_empty(.name),
      classification: (.classification.kind // "unknown"),
      target_frameworks: (.targetFrameworks // []),
      project_sdk: ((.sdks // []) | map(.name // empty) | join("; ")),
      configured_dotnet_sdk: $configured_sdk,
      resolved_dotnet_sdk: (.resolvedSdkVersion // $repo_resolved_sdk // ""),
      is_test: (.isTestProject // false),
      is_packable: (.isPackable // false),
      output_type: text_or_empty(.outputType),
      publication: (.publication // {}),
      status: (
        if any($severities[]; . == "error") then "error"
        elif any($severities[]; . == "warning") then "warning"
        else "ok"
        end
      ),
      diagnostics: (.diagnostics // [])
    };
