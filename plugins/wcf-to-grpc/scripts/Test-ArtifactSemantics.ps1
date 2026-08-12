#Requires -Version 7.5

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ArtifactPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$document = Get-Content -LiteralPath $ArtifactPath -Raw | ConvertFrom-Json -Depth 100
$errors = [System.Collections.Generic.List[string]]::new()
$artifactType = if ($document.PSObject.Properties["artifactType"]) {
    [string] $document.artifactType
}
else {
    "unknown"
}

function Add-Error {
    param([string] $Message)
    $errors.Add($Message)
}

function Get-KnownValue {
    param([AllowNull()] $Resolved)

    if ($null -ne $Resolved -and
        $Resolved.PSObject.Properties["state"] -and
        $Resolved.state -eq "known" -and
        $Resolved.PSObject.Properties["value"]) {
        return $Resolved.value
    }
    return $null
}

function Normalize-ArtifactPath {
    param([string] $Path)
    return ($Path.Replace("\", "/").TrimEnd("/")).ToLowerInvariant()
}

function Test-PathOverlap {
    param([string] $Left, [string] $Right)

    $leftPath = Normalize-ArtifactPath $Left
    $rightPath = Normalize-ArtifactPath $Right
    return $leftPath -eq $rightPath -or
        $leftPath.StartsWith("$rightPath/", [StringComparison]::Ordinal) -or
        $rightPath.StartsWith("$leftPath/", [StringComparison]::Ordinal)
}

function Test-PathCoveredBy {
    param([string] $Child, [string] $Owner)

    $childPath = Normalize-ArtifactPath $Child
    $ownerPath = Normalize-ArtifactPath $Owner
    return $childPath -eq $ownerPath -or
        $childPath.StartsWith("$ownerPath/", [StringComparison]::Ordinal)
}

function Find-DuplicateIds {
    param(
        [AllowNull()] $Value,
        [string] $Path = "$",
        [hashtable] $Seen = @{}
    )

    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) {
        return
    }
    if ($Value -is [System.Collections.IList]) {
        for ($index = 0; $index -lt $Value.Count; $index++) {
            Find-DuplicateIds $Value[$index] "$Path[$index]" $Seen
        }
        return
    }

    foreach ($property in $Value.PSObject.Properties) {
        $propertyPath = "$Path.$($property.Name)"
        if ($property.Name -ceq "id" -and
            $property.Value -is [string] -and
            -not $Path.StartsWith("$.traceLinks", [StringComparison]::Ordinal)) {
            if ($Seen.ContainsKey($property.Value)) {
                Add-Error "Duplicate stable id '$($property.Value)' at $propertyPath and $($Seen[$property.Value])."
            }
            else {
                $Seen[$property.Value] = $propertyPath
            }
        }
        Find-DuplicateIds $property.Value $propertyPath $Seen
    }
}

Find-DuplicateIds $document

if ($artifactType -eq "migration-spec") {
    foreach ($contract in @($document.contracts)) {
        foreach ($message in @($contract.messages)) {
            $messageId = [string] $message.id
            $numbers = @{}
            $names = @{}
            $reservedNumbers = @($message.reservedNumbers)
            $reservedNames = @($message.reservedNames)

            foreach ($field in @($message.fields)) {
                $fieldName = [string] $field.name
                if ($names.ContainsKey($fieldName)) {
                    Add-Error "Message '$messageId' reuses field name '$fieldName'."
                }
                else {
                    $names[$fieldName] = $field.id
                }
                if ($reservedNames -ccontains $fieldName) {
                    Add-Error "Message '$messageId' uses reserved field name '$fieldName'."
                }

                $fieldNumber = Get-KnownValue $field.number
                if ($null -ne $fieldNumber) {
                    $numberKey = [string] $fieldNumber
                    if ($numbers.ContainsKey($numberKey)) {
                        Add-Error "Message '$messageId' reuses field number '$fieldNumber'."
                    }
                    else {
                        $numbers[$numberKey] = $field.id
                    }
                    if ($reservedNumbers -contains [int64] $fieldNumber) {
                        Add-Error "Message '$messageId' uses reserved field number '$fieldNumber'."
                    }
                }
            }
        }
    }

    $packages = @($document.workPackages)
    $packageById = @{}
    foreach ($package in $packages) {
        $packageById[[string] $package.id] = $package
    }

    foreach ($package in $packages) {
        $packageId = [string] $package.id
        foreach ($dependency in @($package.dependencies)) {
            $dependencyId = [string] $dependency.workPackageId
            if (-not $packageById.ContainsKey($dependencyId)) {
                Add-Error "Work package '$packageId' references missing dependency '$dependencyId'."
            }
            elseif ($dependencyId -eq $packageId) {
                Add-Error "Work package '$packageId' depends on itself."
            }
        }
        foreach ($conflictId in @($package.fleet.conflictsWithWorkPackageIds)) {
            if (-not $packageById.ContainsKey([string] $conflictId)) {
                Add-Error "Work package '$packageId' references missing conflict '$conflictId'."
            }
        }

        foreach ($deliverable in @($package.deliverables)) {
            $covered = $false
            foreach ($ownership in @($package.fleet.fileOwnership)) {
                $allowedModes = if ($deliverable.action -eq "verify") {
                    @("exclusive-write", "integration-owner", "shared-read")
                }
                else {
                    @("exclusive-write", "integration-owner")
                }
                if ($ownership.mode -in $allowedModes -and
                    (Test-PathCoveredBy ([string] $deliverable.path) ([string] $ownership.path))) {
                    $covered = $true
                    break
                }
            }
            if (-not $covered) {
                Add-Error "Work package '$packageId' deliverable '$($deliverable.path)' is outside writable file ownership."
            }
        }
    }

    $visitState = @{}
    function Visit-Package {
        param([string] $PackageId, [string[]] $Stack)

        if ($visitState[$PackageId] -eq "visited") {
            return
        }
        if ($visitState[$PackageId] -eq "visiting") {
            Add-Error "Work-package dependency cycle detected: $(($Stack + $PackageId) -join ' -> ')."
            return
        }

        $visitState[$PackageId] = "visiting"
        foreach ($dependency in @($packageById[$PackageId].dependencies)) {
            $dependencyId = [string] $dependency.workPackageId
            if ($packageById.ContainsKey($dependencyId)) {
                Visit-Package $dependencyId ($Stack + $PackageId)
            }
        }
        $visitState[$PackageId] = "visited"
    }
    foreach ($packageId in $packageById.Keys) {
        Visit-Package $packageId @()
    }

    for ($leftIndex = 0; $leftIndex -lt $packages.Count; $leftIndex++) {
        $left = $packages[$leftIndex]
        if ($left.fleet.suitability -ne "eligible") {
            continue
        }
        $leftWave = Get-KnownValue $left.fleet.wave
        for ($rightIndex = $leftIndex + 1; $rightIndex -lt $packages.Count; $rightIndex++) {
            $right = $packages[$rightIndex]
            if ($right.fleet.suitability -ne "eligible") {
                continue
            }
            $rightWave = Get-KnownValue $right.fleet.wave
            if ($null -eq $leftWave -or $leftWave -ne $rightWave) {
                continue
            }
            foreach ($leftOwnership in @($left.fleet.fileOwnership | Where-Object mode -in @("exclusive-write", "integration-owner"))) {
                foreach ($rightOwnership in @($right.fleet.fileOwnership | Where-Object mode -in @("exclusive-write", "integration-owner"))) {
                    if (Test-PathOverlap ([string] $leftOwnership.path) ([string] $rightOwnership.path)) {
                        Add-Error "Fleet-eligible work packages '$($left.id)' and '$($right.id)' overlap writable path ownership in wave '$leftWave'."
                    }
                }
            }
        }
    }
}
elseif ($artifactType -eq "migration-review") {
    $renderedArtifacts = @($document.renderedArtifacts)
    $paths = @{}
    foreach ($artifact in $renderedArtifacts) {
        $path = Normalize-ArtifactPath ([string] $artifact.path)
        if ($paths.ContainsKey($path)) {
            Add-Error "Rendered review artifact path '$($artifact.path)' is duplicated."
        }
        else {
            $paths[$path] = $artifact.kind
        }
    }

    $contractIds = @($document.contractSummary.includedIds | Where-Object { $_ -like "SPEC-*" })
    foreach ($contractId in $contractIds) {
        $matches = @($renderedArtifacts | Where-Object {
            $_.kind -eq "contract" -and @($_.boundIds) -contains $contractId
        })
        if ($matches.Count -ne 1) {
            Add-Error "Contract '$contractId' must have exactly one rendered contract artifact."
        }
    }
    foreach ($workPackageId in @($document.workPackageIds)) {
        $matches = @($renderedArtifacts | Where-Object {
            $_.kind -eq "work-package" -and @($_.boundIds) -contains $workPackageId
        })
        if ($matches.Count -ne 1) {
            Add-Error "Work package '$workPackageId' must have exactly one rendered work-package artifact."
        }
    }
}

[ordered]@{
    artifactPath = (Resolve-Path -LiteralPath $ArtifactPath).Path
    artifactType = $artifactType
    checkedAt = [DateTimeOffset]::UtcNow.ToString("O")
    semanticValid = $errors.Count -eq 0
    errors = @($errors)
} | ConvertTo-Json -Depth 20

if ($errors.Count -gt 0) {
    exit 1
}
