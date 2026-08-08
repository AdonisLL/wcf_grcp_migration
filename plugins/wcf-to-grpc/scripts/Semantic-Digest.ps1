[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet("compute", "verify", "explain", "self-test")]
    [string] $Command,

    [Parameter(Mandatory, Position = 1)]
    [string] $ArtifactPath,

    [Parameter(Position = 2)]
    [string] $ExpectedDigest,

    [string] $RulesPath = (Join-Path $PSScriptRoot "semantic-digest-rules.v1.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$jsonOptions = [System.Text.Json.JsonSerializerOptions]::new()
$jsonOptions.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping

function ConvertTo-CanonicalJson {
    param([AllowNull()] $Value)

    if ($null -eq $Value) {
        return "null"
    }
    if ($Value -is [string]) {
        return [System.Text.Json.JsonSerializer]::Serialize([string] $Value, $jsonOptions)
    }
    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }
    if ($Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]) {
        return [System.Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        $number = [System.Convert]::ToDouble($Value, [Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
            throw "RFC 8785 does not permit non-finite numbers."
        }
        if ($number -eq 0) {
            return "0"
        }
        $serializedNumber = [System.Text.Json.JsonSerializer]::Serialize($number, $jsonOptions)
        return [regex]::Replace(
            $serializedNumber.ToLowerInvariant(),
            "e([+-]?)0+(\d+)$",
            'e$1$2'
        )
    }
    if ($Value -is [System.Collections.IList]) {
        $items = foreach ($item in $Value) {
            ConvertTo-CanonicalJson $item
        }
        return "[" + ($items -join ",") + "]"
    }

    $properties = if ($Value -is [System.Collections.IDictionary]) {
        @($Value.Keys | ForEach-Object {
            [PSCustomObject]@{ Name = [string] $_; Value = $Value[$_] }
        })
    }
    else {
        @($Value.PSObject.Properties | ForEach-Object {
            [PSCustomObject]@{ Name = $_.Name; Value = $_.Value }
        })
    }

    $propertyMap = @{}
    foreach ($property in $properties) {
        $propertyMap[$property.Name] = $property.Value
    }
    [string[]] $propertyNames = @($propertyMap.Keys)
    [Array]::Sort($propertyNames, [StringComparer]::Ordinal)
    $members = foreach ($propertyName in $propertyNames) {
        $property = [PSCustomObject]@{
            Name = $propertyName
            Value = $propertyMap[$propertyName]
        }
        $name = [System.Text.Json.JsonSerializer]::Serialize([string] $property.Name, $jsonOptions)
        $value = ConvertTo-CanonicalJson $property.Value
        "${name}:${value}"
    }
    return "{" + ($members -join ",") + "}"
}

function Remove-ExcludedPath {
    param(
        [AllowNull()] $Value,
        [string[]] $Segments,
        [int] $Index = 0
    )

    if ($null -eq $Value) {
        return
    }

    $segment = $Segments[$Index]
    if ($Value -is [System.Collections.IList]) {
        if ($segment -ne "*") {
            throw "Array exclusions must use a wildcard segment."
        }
        foreach ($item in $Value) {
            if ($Index -lt $Segments.Count - 1) {
                Remove-ExcludedPath $item $Segments ($Index + 1)
            }
        }
        return
    }

    $properties = @($Value.PSObject.Properties)
    $targets = if ($segment -eq "*") {
        $properties
    }
    else {
        @($properties | Where-Object Name -CEQ $segment)
    }

    foreach ($target in $targets) {
        if ($Index -eq $Segments.Count - 1) {
            $Value.PSObject.Properties.Remove($target.Name)
        }
        else {
            Remove-ExcludedPath $target.Value $Segments ($Index + 1)
        }
    }
}

function Get-SemanticDigest {
    param(
        [Parameter(Mandatory)] $Document,
        [Parameter(Mandatory)] $Rules
    )

    $clone = $Document | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $artifactType = if ($clone.PSObject.Properties["artifactType"]) {
        [string] $clone.artifactType
    }
    elseif ($clone.PSObject.Properties["id"] -and [string] $clone.id -match "^WP-") {
        "work-package"
    }
    else {
        "default"
    }
    $exclusions = @($Rules.globalExclusions)
    $artifactRule = $Rules.artifactExclusions.PSObject.Properties[$artifactType]
    if ($null -ne $artifactRule) {
        $exclusions += @($artifactRule.Value)
    }

    foreach ($pointer in $exclusions) {
        if (-not $pointer.StartsWith("/")) {
            throw "Invalid JSON Pointer exclusion: $pointer"
        }
        $segments = @($pointer.Substring(1).Split("/") |
            ForEach-Object { $_.Replace("~1", "/").Replace("~0", "~") })
        Remove-ExcludedPath $clone $segments
    }

    $canonical = ConvertTo-CanonicalJson $clone
    $bytes = [Text.Encoding]::UTF8.GetBytes($canonical)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    return [PSCustomObject]@{
        AlgorithmVersion = $Rules.algorithmVersion
        ArtifactType = $artifactType
        Exclusions = $exclusions
        CanonicalByteLength = $bytes.Length
        Digest = "sha256:$hash"
    }
}

$rules = Get-Content -LiteralPath $RulesPath -Raw | ConvertFrom-Json
if ($Command -eq "self-test") {
    $fixture = Get-Content -LiteralPath $ArtifactPath -Raw | ConvertFrom-Json
    $numericCanonical = ConvertTo-CanonicalJson $fixture.numericCorpus
    if ($numericCanonical -cne $fixture.expectedNumericCanonicalJson) {
        throw "RFC 8785 numeric corpus mismatch: expected $($fixture.expectedNumericCanonicalJson); computed $numericCanonical"
    }
    $base = (Get-SemanticDigest $fixture.base $rules).Digest
    $lifecycle = (Get-SemanticDigest $fixture.lifecycleMutation $rules).Digest
    $semantic = (Get-SemanticDigest $fixture.semanticMutation $rules).Digest
    if ($base -ne $lifecycle) {
        throw "Lifecycle-only mutation changed the semantic digest."
    }
    if ($base -eq $semantic) {
        throw "Semantic mutation did not change the semantic digest."
    }
    Write-Output "Self-test passed ($base)."
    return
}

$artifact = Get-Content -LiteralPath $ArtifactPath -Raw | ConvertFrom-Json
$result = Get-SemanticDigest $artifact $rules
switch ($Command) {
    "compute" {
        Write-Output $result.Digest
    }
    "verify" {
        if ($result.Digest -ne $ExpectedDigest) {
            throw "Digest mismatch: expected $ExpectedDigest; computed $($result.Digest)"
        }
        Write-Output "Digest verified: $($result.Digest)"
    }
    "explain" {
        $result | ConvertTo-Json -Depth 10
    }
}
