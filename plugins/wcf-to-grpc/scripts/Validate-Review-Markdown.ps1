#Requires -Version 7.5

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ReviewJsonPath,

    [Parameter(Mandatory)]
    [string] $ReviewMarkdownPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$review = Get-Content -LiteralPath $ReviewJsonPath -Raw | ConvertFrom-Json
$markdown = Get-Content -LiteralPath $ReviewMarkdownPath -Raw
$errors = [System.Collections.Generic.List[string]]::new()

$approvalState = $review.approval.state
$expectedStateLine = "**Approval state:** ``$approvalState``"
if ([regex]::Matches($markdown, [regex]::Escape($expectedStateLine)).Count -ne 1) {
    $errors.Add("Markdown approval state does not match JSON state '$approvalState'.")
}
$stateMarkers = [regex]::Matches(
    $markdown,
    '(?im)^\*\*Approval state:\*\*\s+`(draft|review-requested|approved|rejected|superseded|not-applicable)`\s*$'
)
if ($stateMarkers.Count -ne 1) {
    $errors.Add("Markdown must contain exactly one structured approval-state statement.")
}
foreach ($staleState in @("draft", "review-requested", "approved", "rejected", "superseded", "not-applicable")) {
    if ($staleState -eq $approvalState) {
        continue
    }
    $stalePatterns = @(
        "(?i)\b(?:bundle|review|approval(?:\s+state)?)\s+(?:is|remains|:)\s+`?$([regex]::Escape($staleState))`?\b",
        "(?i)\b$([regex]::Escape($staleState))\s+(?:bundle|review|approval)\b"
    )
    foreach ($pattern in $stalePatterns) {
        if ($markdown -match $pattern) {
            $errors.Add("Markdown contains stale lifecycle prose for '$staleState'.")
            break
        }
    }
}
if ($approvalState -eq "approved" -and
    $markdown -match "(?i)\bnot[- ](?:yet[- ])?executable\b") {
    $errors.Add("Approved review Markdown still describes the bundle as non-executable.")
}
if ($approvalState -eq "approved" -and
    $markdown -match "(?im)^#{1,6}\s+Draft\s+(?:architecture|contracts|roadmap|work packages)\b") {
    $errors.Add("Approved review Markdown retains a draft lifecycle heading.")
}
if ($markdown -notmatch [regex]::Escape($review.semanticDigest)) {
    $errors.Add("Markdown does not contain the current semantic digest.")
}
foreach ($decisionId in @($review.blockingDecisionIds)) {
    if ($markdown -notmatch [regex]::Escape($decisionId)) {
        $errors.Add("Markdown omits blocking decision '$decisionId'.")
    }
}
foreach ($item in @($review.offlineHandoffItems)) {
    if ($markdown -notmatch [regex]::Escape($item.decisionId) -or
        $markdown -notmatch [regex]::Escape($item.gate)) {
        $errors.Add("Markdown omits offline handoff item '$($item.decisionId)' or its gate.")
    }
}
foreach ($artifact in @($review.renderedArtifacts)) {
    if ($markdown -notmatch [regex]::Escape($artifact.path)) {
        $errors.Add("Markdown omits rendered review artifact path '$($artifact.path)'.")
    }
    if ($markdown -notmatch [regex]::Escape($artifact.contentDigest)) {
        $errors.Add("Markdown omits content digest '$($artifact.contentDigest)' for '$($artifact.path)'.")
    }
    foreach ($boundId in @($artifact.boundIds)) {
        if ($markdown -notmatch [regex]::Escape($boundId)) {
            $errors.Add("Markdown omits digest-bound id '$boundId' for '$($artifact.path)'.")
        }
    }
}

[ordered]@{
    reviewJsonPath = (Resolve-Path -LiteralPath $ReviewJsonPath).Path
    reviewMarkdownPath = (Resolve-Path -LiteralPath $ReviewMarkdownPath).Path
    checkedAt = [DateTimeOffset]::UtcNow.ToString("O")
    consistent = $errors.Count -eq 0
    errors = @($errors)
} | ConvertTo-Json -Depth 10

if ($errors.Count -gt 0) {
    exit 1
}
