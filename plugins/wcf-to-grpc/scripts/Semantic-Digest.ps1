#Requires -Version 7.5

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

$invariantCulture = [Globalization.CultureInfo]::InvariantCulture

function Open-JsonDocument {
    param([Parameter(Mandatory)][string] $Path)

    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $false
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.MaxDepth = 256
    return [System.Text.Json.JsonDocument]::Parse(
        [System.IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8),
        $options
    )
}

function Open-JsonText {
    param([Parameter(Mandatory)][string] $Json)

    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $false
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.MaxDepth = 256
    return [System.Text.Json.JsonDocument]::Parse($Json, $options)
}

function Assert-NoDuplicateJsonKeys {
    param([Parameter(Mandatory)][System.Text.Json.JsonElement] $Element)

    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            if (-not $keys.Add($property.Name)) {
                throw "Duplicate JSON object key '$($property.Name)' is not allowed."
            }
            Assert-NoDuplicateJsonKeys $property.Value
        }
    }
    elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) {
            Assert-NoDuplicateJsonKeys $item
        }
    }
}

function Get-JsonProperty {
    param(
        [Parameter(Mandatory)][System.Text.Json.JsonElement] $Object,
        [Parameter(Mandatory)][string] $Name,
        [switch] $Required
    )

    if ($Object.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
        if ($Required) {
            throw "Expected a JSON object while reading '$Name'."
        }
        return $null
    }

    foreach ($property in $Object.EnumerateObject()) {
        if ($property.Name -ceq $Name) {
            return $property.Value
        }
    }

    if ($Required) {
        throw "Required JSON property '$Name' is missing."
    }
    return $null
}

function Get-JsonStringArray {
    param([Parameter(Mandatory)][System.Text.Json.JsonElement] $Value)

    if ($Value.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
        throw "Expected a JSON array."
    }
    return @($Value.EnumerateArray() | ForEach-Object {
        if ($_.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
            throw "Expected a JSON string array."
        }
        $_.GetString()
    })
}

function ConvertTo-JsonPointerSegments {
    param([Parameter(Mandatory)][string] $Pointer)

    if (-not $Pointer.StartsWith("/", [StringComparison]::Ordinal)) {
        throw "Invalid JSON Pointer exclusion: $Pointer"
    }
    return @($Pointer.Substring(1).Split("/") |
        ForEach-Object { $_.Replace("~1", "/").Replace("~0", "~") })
}

function Read-DigestRules {
    param([Parameter(Mandatory)][string] $Path)

    $document = Open-JsonDocument $Path
    try {
        $root = $document.RootElement
        $algorithmVersion = (Get-JsonProperty $root "algorithmVersion" -Required).GetString()
        $globalExclusions = Get-JsonStringArray (Get-JsonProperty $root "globalExclusions" -Required)
        $artifactExclusions = [System.Collections.Generic.Dictionary[string, object]]::new(
            [StringComparer]::Ordinal
        )
        $artifactRules = Get-JsonProperty $root "artifactExclusions" -Required
        foreach ($property in $artifactRules.EnumerateObject()) {
            $artifactExclusions.Add($property.Name, @(Get-JsonStringArray $property.Value))
        }
        return [PSCustomObject]@{
            AlgorithmVersion = $algorithmVersion
            GlobalExclusions = @($globalExclusions)
            ArtifactExclusions = $artifactExclusions
        }
    }
    finally {
        $document.Dispose()
    }
}

function Test-ExcludedPath {
    param(
        [Parameter(Mandatory)][string[]] $Path,
        [AllowEmptyCollection()][Parameter(Mandatory)][object[]] $Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($pattern.Count -ne $Path.Count) {
            continue
        }
        $matches = $true
        for ($index = 0; $index -lt $Path.Count; $index++) {
            if ($pattern[$index] -ne "*" -and $pattern[$index] -cne $Path[$index]) {
                $matches = $false
                break
            }
        }
        if ($matches) {
            return $true
        }
    }
    return $false
}

function ConvertTo-CanonicalString {
    param([AllowEmptyString()][Parameter(Mandatory)][string] $Value)

    $builder = [Text.StringBuilder]::new($Value.Length + 2)
    [void] $builder.Append('"')
    for ($index = 0; $index -lt $Value.Length; $index++) {
        $code = [int] $Value[$index]
        if ($code -eq 8) {
            [void] $builder.Append('\b')
            continue
        }
        if ($code -eq 9) {
            [void] $builder.Append('\t')
            continue
        }
        if ($code -eq 10) {
            [void] $builder.Append('\n')
            continue
        }
        if ($code -eq 12) {
            [void] $builder.Append('\f')
            continue
        }
        if ($code -eq 13) {
            [void] $builder.Append('\r')
            continue
        }
        if ($code -eq 34) {
            [void] $builder.Append('\"')
            continue
        }
        if ($code -eq 92) {
            [void] $builder.Append('\\')
            continue
        }

        if ($code -lt 0x20) {
            [void] $builder.Append("\u$($code.ToString("x4", $invariantCulture))")
            continue
        }
        if ($code -ge 0xD800 -and $code -le 0xDBFF) {
            if ($index + 1 -ge $Value.Length) {
                throw "RFC 8785 does not permit an unpaired high surrogate."
            }
            $low = [int] $Value[$index + 1]
            if ($low -lt 0xDC00 -or $low -gt 0xDFFF) {
                throw "RFC 8785 does not permit an unpaired high surrogate."
            }
            [void] $builder.Append($Value[$index])
            [void] $builder.Append($Value[$index + 1])
            $index++
            continue
        }
        if ($code -ge 0xDC00 -and $code -le 0xDFFF) {
            throw "RFC 8785 does not permit an unpaired low surrogate."
        }
        [void] $builder.Append($Value[$index])
    }
    [void] $builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-CanonicalNumber {
    param([Parameter(Mandatory)][System.Text.Json.JsonElement] $Value)

    try {
        $number = $Value.GetDouble()
    }
    catch {
        throw "RFC 8785 number is outside the IEEE 754 double-precision range: $($Value.GetRawText())"
    }
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        throw "RFC 8785 does not permit non-finite numbers."
    }
    if ($number -eq 0) {
        return "0"
    }

    $sign = if ($number -lt 0) { "-" } else { "" }
    $roundTrip = [Math]::Abs($number).ToString("R", $invariantCulture).ToLowerInvariant()
    $exponent = 0
    $exponentIndex = $roundTrip.IndexOf("e", [StringComparison]::Ordinal)
    if ($exponentIndex -ge 0) {
        $exponent = [int]::Parse($roundTrip.Substring($exponentIndex + 1), $invariantCulture)
        $coefficient = $roundTrip.Substring(0, $exponentIndex)
    }
    else {
        $coefficient = $roundTrip
    }

    $decimalIndex = $coefficient.IndexOf(".", [StringComparison]::Ordinal)
    if ($decimalIndex -lt 0) {
        $decimalIndex = $coefficient.Length
    }
    $digits = $coefficient.Replace(".", "")
    $leadingZeroCount = 0
    while ($leadingZeroCount -lt $digits.Length -and $digits[$leadingZeroCount] -eq "0") {
        $leadingZeroCount++
    }
    $digits = $digits.Substring($leadingZeroCount)
    $decimalPosition = $decimalIndex + $exponent - $leadingZeroCount
    $digits = $digits.TrimEnd("0")
    $digitCount = $digits.Length

    if ($digitCount -le $decimalPosition -and $decimalPosition -le 21) {
        return $sign + $digits + ("0" * ($decimalPosition - $digitCount))
    }
    if (0 -lt $decimalPosition -and $decimalPosition -le 21) {
        return $sign + $digits.Substring(0, $decimalPosition) + "." + $digits.Substring($decimalPosition)
    }
    if (-6 -lt $decimalPosition -and $decimalPosition -le 0) {
        return $sign + "0." + ("0" * (-$decimalPosition)) + $digits
    }

    $mantissa = $digits.Substring(0, 1)
    if ($digitCount -gt 1) {
        $mantissa += "." + $digits.Substring(1)
    }
    $scientificExponent = $decimalPosition - 1
    $exponentSign = if ($scientificExponent -ge 0) { "+" } else { "-" }
    return "$sign$mantissa" + "e" + $exponentSign +
        [Math]::Abs($scientificExponent).ToString($invariantCulture)
}

function ConvertTo-CanonicalJson {
    param(
        [Parameter(Mandatory)][System.Text.Json.JsonElement] $Value,
        [string[]] $Path = @(),
        [AllowEmptyCollection()][object[]] $ExclusionPatterns = @()
    )

    switch ($Value.ValueKind) {
        ([System.Text.Json.JsonValueKind]::Null) { return "null" }
        ([System.Text.Json.JsonValueKind]::True) { return "true" }
        ([System.Text.Json.JsonValueKind]::False) { return "false" }
        ([System.Text.Json.JsonValueKind]::String) {
            return ConvertTo-CanonicalString $Value.GetString()
        }
        ([System.Text.Json.JsonValueKind]::Number) {
            return ConvertTo-CanonicalNumber $Value
        }
        ([System.Text.Json.JsonValueKind]::Array) {
            $items = foreach ($item in $Value.EnumerateArray()) {
                ConvertTo-CanonicalJson $item ($Path + "*") $ExclusionPatterns
            }
            return "[" + ($items -join ",") + "]"
        }
        ([System.Text.Json.JsonValueKind]::Object) {
            $seenNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $properties = [System.Collections.Generic.List[object]]::new()
            foreach ($property in $Value.EnumerateObject()) {
                if (-not $seenNames.Add($property.Name)) {
                    throw "RFC 8785 input contains duplicate property name '$($property.Name)'."
                }
                $propertyPath = @($Path + $property.Name)
                if (-not (Test-ExcludedPath $propertyPath $ExclusionPatterns)) {
                    $properties.Add([PSCustomObject]@{
                        Name = $property.Name
                        Value = $property.Value
                        Path = $propertyPath
                    })
                }
            }
            $properties.Sort([System.Comparison[object]] {
                param($left, $right)
                [StringComparer]::Ordinal.Compare($left.Name, $right.Name)
            })
            $members = foreach ($property in $properties) {
                $name = ConvertTo-CanonicalString $property.Name
                $canonicalValue = ConvertTo-CanonicalJson $property.Value $property.Path $ExclusionPatterns
                "${name}:${canonicalValue}"
            }
            return "{" + ($members -join ",") + "}"
        }
        default {
            throw "Unsupported JSON value kind: $($Value.ValueKind)"
        }
    }
}

function Get-ArtifactType {
    param([Parameter(Mandatory)][System.Text.Json.JsonElement] $Document)

    $artifactType = Get-JsonProperty $Document "artifactType"
    if ($null -ne $artifactType -and
        $artifactType.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
        return $artifactType.GetString()
    }
    $id = Get-JsonProperty $Document "id"
    if ($null -ne $id -and
        $id.ValueKind -eq [System.Text.Json.JsonValueKind]::String -and
        $id.GetString().StartsWith("WP-", [StringComparison]::Ordinal)) {
        return "work-package"
    }
    return "default"
}

function Get-SemanticDigest {
    param(
        [Parameter(Mandatory)][System.Text.Json.JsonElement] $Document,
        [Parameter(Mandatory)] $Rules
    )

    $artifactType = Get-ArtifactType $Document
    $exclusions = [System.Collections.Generic.List[string]]::new()
    foreach ($pointer in $Rules.GlobalExclusions) {
        $exclusions.Add($pointer)
    }
    if ($Rules.ArtifactExclusions.ContainsKey($artifactType)) {
        foreach ($pointer in $Rules.ArtifactExclusions[$artifactType]) {
            $exclusions.Add($pointer)
        }
    }
    $patterns = @($exclusions | ForEach-Object { , @(ConvertTo-JsonPointerSegments $_) })
    $canonical = ConvertTo-CanonicalJson $Document @() $patterns
    $bytes = [Text.Encoding]::UTF8.GetBytes($canonical)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    return [PSCustomObject]@{
        AlgorithmVersion = $Rules.AlgorithmVersion
        ArtifactType = $artifactType
        Exclusions = @($exclusions)
        CanonicalByteLength = $bytes.Length
        Digest = "sha256:$hash"
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string] $Value)

    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

$rules = Read-DigestRules $RulesPath
if ($Command -eq "self-test") {
    $fixtureDocument = Open-JsonDocument $ArtifactPath
    try {
        $fixture = $fixtureDocument.RootElement
        $numericCorpus = Get-JsonProperty $fixture "numericCorpus" -Required
        $numericCanonical = ConvertTo-CanonicalJson $numericCorpus
        $expectedNumeric = (Get-JsonProperty $fixture "expectedNumericCanonicalJson" -Required).GetString()
        if ($numericCanonical -cne $expectedNumeric) {
            throw "RFC 8785 numeric corpus mismatch: expected $expectedNumeric; computed $numericCanonical"
        }

        $stringCorpus = Get-JsonProperty $fixture "stringCorpus" -Required
        $stringCanonical = ConvertTo-CanonicalJson $stringCorpus
        $stringCanonicalHex = [Convert]::ToHexString(
            [Text.Encoding]::UTF8.GetBytes($stringCanonical)
        ).ToLowerInvariant()
        $expectedStringHex = (Get-JsonProperty $fixture "expectedStringCanonicalUtf8Hex" -Required).GetString()
        if ($stringCanonicalHex -cne $expectedStringHex) {
            throw "RFC 8785 string corpus mismatch: expected UTF-8 $expectedStringHex; computed $stringCanonicalHex"
        }

        $caseDistinctJson = (Get-JsonProperty $fixture "caseDistinctJson" -Required).GetString()
        $caseDocument = Open-JsonText $caseDistinctJson
        try {
            $caseDistinctCanonical = ConvertTo-CanonicalJson $caseDocument.RootElement
        }
        finally {
            $caseDocument.Dispose()
        }
        $expectedCaseDistinct = (Get-JsonProperty $fixture "expectedCaseDistinctCanonicalJson" -Required).GetString()
        if ($caseDistinctCanonical -cne $expectedCaseDistinct) {
            throw "Case-distinct key corpus mismatch: expected $expectedCaseDistinct; computed $caseDistinctCanonical"
        }

        $duplicateKeyJson = (Get-JsonProperty $fixture "duplicateKeyJson" -Required).GetString()
        $duplicateRejected = $false
        try {
            $duplicateDocument = Open-JsonText $duplicateKeyJson
            try {
                Assert-NoDuplicateJsonKeys $duplicateDocument.RootElement
            }
            finally {
                $duplicateDocument.Dispose()
            }
        }
        catch {
            $duplicateRejected = $_.Exception.Message -match "duplicate"
        }
        if (-not $duplicateRejected) {
            throw "Duplicate-key JSON corpus was not rejected."
        }

        $lifecycleCases = Get-JsonProperty $fixture "lifecycleCases" -Required
        $lifecycleCaseCount = 0
        foreach ($testCase in $lifecycleCases.EnumerateArray()) {
            $lifecycleCaseCount++
            $name = (Get-JsonProperty $testCase "name" -Required).GetString()
            $base = (Get-SemanticDigest (Get-JsonProperty $testCase "base" -Required) $rules).Digest
            $lifecycle = (Get-SemanticDigest (Get-JsonProperty $testCase "lifecycleMutation" -Required) $rules).Digest
            $semantic = (Get-SemanticDigest (Get-JsonProperty $testCase "semanticMutation" -Required) $rules).Digest
            if ($base -ne $lifecycle) {
                throw "${name}: lifecycle-only mutation changed the semantic digest."
            }
            if ($base -eq $semantic) {
                throw "${name}: semantic mutation did not change the semantic digest."
            }
        }

        $corpusDigest = Get-Sha256 ($numericCanonical + "`n" + $stringCanonical + "`n" + $caseDistinctCanonical)
        Write-Output "Self-test passed ($lifecycleCaseCount lifecycle cases; corpus sha256:$corpusDigest)."
        return
    }
    finally {
        $fixtureDocument.Dispose()
    }
}

$artifactDocument = Open-JsonDocument $ArtifactPath
try {
    $result = Get-SemanticDigest $artifactDocument.RootElement $rules
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
}
finally {
    $artifactDocument.Dispose()
}
