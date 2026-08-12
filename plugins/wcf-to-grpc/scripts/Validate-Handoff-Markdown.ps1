#Requires -Version 7.5

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $HandoffJsonPath,

    [Parameter(Mandatory)]
    [string] $HandoffMarkdownPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$handoff = Get-Content -LiteralPath $HandoffJsonPath -Raw | ConvertFrom-Json -Depth 100
$markdown = Get-Content -LiteralPath $HandoffMarkdownPath -Raw
$errors = [System.Collections.Generic.List[string]]::new()

function Require-MarkdownValue {
    param([string] $Value, [string] $Description)

    if (-not [string]::IsNullOrWhiteSpace($Value) -and
        $markdown -notmatch [regex]::Escape($Value)) {
        $errors.Add("Markdown omits $Description '$Value'.")
    }
}

Require-MarkdownValue ([string] $handoff.codeCompletion.status) "code-completion status"
Require-MarkdownValue ([string] $handoff.solutionLayout.mode) "solution-layout mode"
Require-MarkdownValue ([string] $handoff.solutionLayout.grpcRoot) "gRPC root"
Require-MarkdownValue ([string] $handoff.solutionLayout.wcfSourceHandling) "WCF source-handling mode"

if ($handoff.codeCompletion.sourceRevision.state -eq "known") {
    Require-MarkdownValue ([string] $handoff.codeCompletion.sourceRevision.value) "source revision"
}
foreach ($deliverable in @($handoff.deliverables)) {
    Require-MarkdownValue ([string] $deliverable.path) "deliverable path"
}
foreach ($validation in @($handoff.localValidation)) {
    Require-MarkdownValue ([string] $validation.validationId) "validation id"
    Require-MarkdownValue ([string] $validation.outcome) "validation outcome"
}
foreach ($gap in @($handoff.codeGaps)) {
    Require-MarkdownValue ([string] $gap.id) "code-gap id"
}
foreach ($obligation in @($handoff.offlineObligations)) {
    Require-MarkdownValue ([string] $obligation.id) "offline-obligation id"
    Require-MarkdownValue ([string] $obligation.category) "offline-obligation category"
    Require-MarkdownValue ([string] $obligation.executionState) "offline-obligation execution state"
    Require-MarkdownValue ([string] $obligation.nextAction) "offline-obligation next action"
}
if ($markdown -notmatch "(?i)WCF state:\*\*\s+Active and unchanged") {
    $errors.Add("Markdown does not state that WCF remains active and unchanged.")
}
$normalizedMarkdown = ($markdown -replace "\s+", " ").Trim()
$requiredDisclaimer = "Code completion is not deployment readiness, runtime parity, cutover authorization, live rollback completion, or WCF retirement authorization."
if (-not $normalizedMarkdown.Contains($requiredDisclaimer, [StringComparison]::Ordinal)) {
    $errors.Add("Markdown omits the code-only handoff disclaimer.")
}

[ordered]@{
    handoffJsonPath = (Resolve-Path -LiteralPath $HandoffJsonPath).Path
    handoffMarkdownPath = (Resolve-Path -LiteralPath $HandoffMarkdownPath).Path
    checkedAt = [DateTimeOffset]::UtcNow.ToString("O")
    consistent = $errors.Count -eq 0
    errors = @($errors)
} | ConvertTo-Json -Depth 10

if ($errors.Count -gt 0) {
    exit 1
}
