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
}

try {
    $null = Test-Json -LiteralPath $resolvedArtifact -SchemaFile $resolvedSchema -ErrorAction Stop
    $result.valid = $true
}
catch {
    $result.error = $_.Exception.Message
}

$result | ConvertTo-Json -Depth 10
if (-not $result.valid) {
    exit 1
}
