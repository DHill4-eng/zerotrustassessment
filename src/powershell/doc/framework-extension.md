# Extending ZeroTrustAssessment for Additional Frameworks

This repository supports framework-aware execution so the existing pipeline can include additional assessment modules such as `CyberEssentialsPlus`, `SecureModernWorkplace`, and `MonthlyServiceReport`.

## Module selection during assessment run

Use framework selection directly:

```powershell
Invoke-ZtAssessment -Framework ZeroTrust,CyberEssentialsPlus
```

Or prompt interactively:

```powershell
Invoke-ZtAssessment -PromptFrameworkSelection
```

## Cyber Essentials Plus (CE+) support

CE+ uses control mappings in:

- `assets/frameworks/CyberEssentialsPlus.controls.json`

The exported assessment JSON includes:

- `FrameworkAssessments.CyberEssentialsPlus.ControlSummary`
- `FrameworkAssessments.CyberEssentialsPlus.Controls[]`

## Secure Modern Workplace (SMW) policy baseline support

SMW policy validation uses live Microsoft Graph queries and compares current tenant objects against policy baseline JSON.

Baseline file path:

- `assets/frameworks/SecureModernWorkplace.policies.json`

Each policy object supports:

- `PolicyId` and `Title`
- `ApiVersion` (`v1.0` or `beta`)
- `RelativeUri` (Graph path)
- `CollectionPath` (where to find list in response, default `value`)
- `MatchMode` (`AnyObjectMatchesAllRules`, `FirstObjectMatchesAllRules`, `AllObjectsMatchAllRules`)
- `LogicalOperator` (`All` or `Any`, defaults to `All`)
- Optional Graph query controls: `QueryParameters`, `Filter`, `Select`, `Top`
- `Rules[]` where each rule has:
  - `Path` (dot notation path in object)
  - `Operator` (`Equals`, `NotEquals`, `Contains`, `NotContains`, `In`, `NotIn`, `Exists`, `GreaterThan`, `GreaterOrEquals`, `LessThan`, `LessOrEquals`, `MatchesRegex`)
  - `ExpectedValue` (not required for `Exists`)

Output section in report JSON:

- `FrameworkAssessments.SecureModernWorkplace.Summary`
- `FrameworkAssessments.SecureModernWorkplace.Policies[]`

Policy status values are:

- `Present` (at least one object matches rules)
- `Missing` (no matching object)
- `Error` (query or evaluation failure)

## How to provide your SMW JSON policy pack

1. Add your JSON file(s) under `src/powershell/assets/frameworks/`.
2. Use the schema in `SecureModernWorkplace.policies.json`.
3. Tell us the filenames; we can then tune query and rule operators for each policy type.

This lets the tool perform rapid “already in place vs missing” checks for your deployment baselines.

## Using policy checkpoint JSON files directly

Place your policy checkpoint JSON files directly in `src/powershell/assets/frameworks/` using the naming pattern:

- `SecureModernWorkplace.policies.json`
- `SecureModernWorkplace.<any-name>.policies.json`

All matching files are merged during assessment so you can split checkpoints by platform/workload (for example `SecureModernWorkplace.intune.policies.json` and `SecureModernWorkplace.entra.policies.json`). This allows you to upload policy sets directly without ZIP import tooling.
