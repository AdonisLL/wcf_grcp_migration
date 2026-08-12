#Requires -Version 7.5

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ArtifactPath,

    [Parameter(Mandatory)]
    [string] $SchemaPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath).Path
$resolvedSchema = (Resolve-Path -LiteralPath $SchemaPath).Path
$result = [ordered]@{
    artifactPath = $resolvedArtifact
    schemaPath = $resolvedSchema
    draft = "2020-12"
    validatedAt = [DateTimeOffset]::UtcNow.ToString("O")
    valid = $false
    error = $null
    semanticValidation = $null
}

try {
    $null = Test-Json -LiteralPath $resolvedArtifact -SchemaFile $resolvedSchema -ErrorAction Stop
    $semanticScript = Join-Path $PSScriptRoot "Test-ArtifactSemantics.ps1"
    $semanticOutput = & $semanticScript -ArtifactPath $resolvedArtifact | ConvertFrom-Json
    $result.semanticValidation = $semanticOutput
    if (-not $semanticOutput.semanticValid) {
        throw "Artifact semantic validation failed."
    }
    $result.valid = $true
}
catch {
    $result.error = $_.Exception.Message
}

$result | ConvertTo-Json -Depth 10
if (-not $result.valid) {
    exit 1
}
