#Requires -Version 7.5

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Checks = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()
$pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $pluginRoot "../.."))
$marketplacePath = Join-Path $repoRoot ".github/plugin/marketplace.json"
$repositoryPluginManifestPath = Join-Path $repoRoot "plugin.json"
$pluginManifestPath = Join-Path $pluginRoot "plugin.json"
$fixtureRoot = Join-Path $pluginRoot "tests/fixtures"
$docsRoot = Join-Path $repoRoot "docs"
$fixtureSchemaPath = Join-Path $fixtureRoot "fixture-expectations.schema.json"
$stableIdPattern = "^(?:INV|DLOG|MRES|MREV|MMAP|MRSK|MBLK|MDEF|MSPEC|ISET|CHOFF|OBL|REPO|SOL|PRJ|HOST|SVC|OP|DC|FLD|END|CON|DEP|EVD|RSK|QST|DEC|OPT|APV|ATT|SPEC|RPC|MSG|PF|PHS|WP|AC|VAL|ISSUE|LBL|TRC|IMP|VRPT|VF|FIX)-[a-z0-9]+(?:-[a-z0-9]+)*$"

function Add-Check {
    param(
        [bool] $Condition,
        [string] $Message
    )

    $script:Checks++
    if (-not $Condition) {
        $script:Failures.Add($Message)
    }
}

function Get-PropertyValue {
    param(
        [AllowNull()] $Object,
        [string] $Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Read-JsonFile {
    param([string] $Path)

    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        $script:Failures.Add("Invalid JSON: $Path ($($_.Exception.Message))")
        return $null
    }
}

function Test-AllowedProperties {
    param(
        [AllowNull()] $Object,
        [string[]] $Allowed,
        [string] $Context
    )

    if ($null -eq $Object) {
        Add-Check $false "$Context is missing."
        return
    }

    foreach ($property in $Object.PSObject.Properties) {
        Add-Check ($property.Name -in $Allowed) "$Context contains unsupported field '$($property.Name)'."
    }
}

function Resolve-ComponentPath {
    param(
        [string] $BasePath,
        [string] $RelativePath
    )

    $portablePath = $RelativePath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $portablePath))
}

function Read-Frontmatter {
    param([string] $Path)

    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "---") {
        Add-Check $false "Missing YAML frontmatter in $Path."
        return @{}
    }

    $end = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq "---") {
            $end = $index
            break
        }
    }

    if ($end -lt 0) {
        Add-Check $false "Unterminated YAML frontmatter in $Path."
        return @{}
    }

    $frontmatter = @{}
    $index = 1
    while ($index -lt $end) {
        if ($lines[$index] -notmatch "^([A-Za-z][A-Za-z0-9_-]*):(?:\s*(.*))?$") {
            if (-not [string]::IsNullOrWhiteSpace($lines[$index])) {
                Add-Check $false "Unsupported YAML frontmatter syntax at $Path line $($index + 1)."
            }
            $index++
            continue
        }

        $key = $Matches[1]
        $value = [string] $Matches[2]
        if ($value -in @(">", "|") -or
            ([string]::IsNullOrEmpty($value) -and
                $index + 1 -lt $end -and $lines[$index + 1] -match "^\s+")) {
            $folded = $value -eq ">"
            $continuation = [System.Collections.Generic.List[string]]::new()
            $index++
            while ($index -lt $end -and
                ($lines[$index] -match "^\s+" -or [string]::IsNullOrWhiteSpace($lines[$index]))) {
                $continuation.Add($lines[$index].Trim())
                $index++
            }
            $value = if ($folded) {
                ($continuation -join " ").Trim()
            }
            else {
                ($continuation -join "`n").Trim()
            }
        }
        else {
            $value = $value.Trim()
            $index++
        }
        $frontmatter[$key] = $value
    }

    return $frontmatter
}

function Get-MarkdownAnchors {
    param([string] $Path)

    $anchors = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $counts = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -notmatch "^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$") {
            continue
        }

        $heading = $Matches[1]
        $heading = [regex]::Replace($heading, "\[([^\]]+)\]\([^)]+\)", '$1')
        $heading = [regex]::Replace($heading, "<[^>]+>", "")
        $heading = [regex]::Replace($heading, "[\x60*]", "")
        $slug = $heading.ToLowerInvariant()
        $slug = [regex]::Replace($slug, "[^\p{L}\p{Nd}\s_-]", "")
        $slug = [regex]::Replace($slug.Trim(), "\s+", "-")

        if (-not $counts.ContainsKey($slug)) {
            $counts[$slug] = 0
            $null = $anchors.Add($slug)
        }
        else {
            $counts[$slug]++
            $null = $anchors.Add("$slug-$($counts[$slug])")
        }
    }

    return $anchors
}

function Resolve-JsonPointer {
    param(
        [AllowNull()] $Document,
        [string] $Fragment
    )

    if ([string]::IsNullOrEmpty($Fragment) -or $Fragment -eq "#") {
        return $true
    }
    if (-not $Fragment.StartsWith("#/")) {
        return $false
    }

    $current = $Document
    foreach ($encodedPart in $Fragment.Substring(2).Split("/")) {
        $part = [System.Uri]::UnescapeDataString($encodedPart).Replace("~1", "/").Replace("~0", "~")
        if ($null -eq $current) {
            return $false
        }

        if ($current -is [System.Collections.IList] -and $part -match "^\d+$") {
            $position = [int]$part
            if ($position -ge $current.Count) {
                return $false
            }
            $current = $current[$position]
            continue
        }

        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) {
            return $false
        }
        $current = $property.Value
    }

    return $true
}

function Test-StableIds {
    param(
        [AllowNull()] $Node,
        [string] $Context
    )

    if ($null -eq $Node -or $Node -is [string] -or $Node -is [System.ValueType]) {
        return
    }

    if ($Node -is [System.Collections.IEnumerable] -and
        $Node -isnot [System.Management.Automation.PSCustomObject]) {
        $siblingIds = @()
        $position = 0
        foreach ($item in $Node) {
            $id = Get-PropertyValue $item "id"
            if ($id -is [string] -and $id -cmatch "^[A-Z]+-") {
                $siblingIds += $id
            }
            Test-StableIds $item "$Context[$position]"
            $position++
        }

        foreach ($duplicate in $siblingIds | Group-Object | Where-Object Count -gt 1) {
            Add-Check $false "$Context contains duplicate stable ID '$($duplicate.Name)'."
        }
        return
    }

    foreach ($property in $Node.PSObject.Properties) {
        if ($property.Name -match "(?i)(^id$|Id$|Ids$)") {
            foreach ($value in @($property.Value)) {
                if ($value -is [string] -and $value -cmatch "^[A-Z]+-") {
                    Add-Check ($value -match $stableIdPattern) "$Context.$($property.Name) has invalid stable ID '$value'."
                }
            }
        }
        Test-StableIds $property.Value "$Context.$($property.Name)"
    }
}

function Test-DependencyDag {
    param(
        [object[]] $Nodes,
        [scriptblock] $DependencySelector,
        [string] $Context
    )

    $nodeMap = @{}
    foreach ($node in $Nodes) {
        $id = Get-PropertyValue $node "id"
        Add-Check (-not [string]::IsNullOrWhiteSpace($id)) "$Context contains a node without an id."
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }
        Add-Check (-not $nodeMap.ContainsKey($id)) "$Context contains duplicate node '$id'."
        $nodeMap[$id] = $node
    }

    $indegree = @{}
    $dependents = @{}
    foreach ($id in $nodeMap.Keys) {
        $indegree[$id] = 0
        $dependents[$id] = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($id in $nodeMap.Keys) {
        $dependencies = @(& $DependencySelector $nodeMap[$id])
        foreach ($dependency in $dependencies) {
            Add-Check ($nodeMap.ContainsKey($dependency)) "$Context node '$id' depends on missing node '$dependency'."
            if ($nodeMap.ContainsKey($dependency)) {
                $indegree[$id]++
                $dependents[$dependency].Add($id)
            }
        }
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($id in $nodeMap.Keys) {
        if ($indegree[$id] -eq 0) {
            $queue.Enqueue($id)
        }
    }

    $visited = 0
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        $visited++
        foreach ($dependent in $dependents[$id]) {
            $indegree[$dependent]--
            if ($indegree[$dependent] -eq 0) {
                $queue.Enqueue($dependent)
            }
        }
    }

    Add-Check ($visited -eq $nodeMap.Count) "$Context contains a dependency cycle."
}

function Test-PathsOverlap {
    param(
        [string] $Left,
        [string] $Right
    )

    $leftPath = $Left.Replace("\", "/").TrimEnd("/")
    $rightPath = $Right.Replace("\", "/").TrimEnd("/")
    return $leftPath -eq $rightPath -or
        $leftPath.StartsWith("$rightPath/", [StringComparison]::OrdinalIgnoreCase) -or
        $rightPath.StartsWith("$leftPath/", [StringComparison]::OrdinalIgnoreCase)
}

function Test-WavePlan {
    param(
        [object[]] $WorkPackages,
        [object[]] $Phases,
        [string] $Context
    )

    $packagesById = @{}
    foreach ($package in $WorkPackages) {
        $packagesById[(Get-PropertyValue $package "id")] = $package
    }

    foreach ($package in $WorkPackages) {
        $packageId = Get-PropertyValue $package "id"
        $fleet = Get-PropertyValue $package "fleet"
        $wave = Get-PropertyValue (Get-PropertyValue $fleet "wave") "value"
        foreach ($dependency in @(Get-PropertyValue $package "dependencies")) {
            if ((Get-PropertyValue $dependency "type") -ne "hard") {
                continue
            }
            $dependencyId = Get-PropertyValue $dependency "workPackageId"
            if (-not $packagesById.ContainsKey($dependencyId)) {
                continue
            }
            $dependencyWave = Get-PropertyValue (Get-PropertyValue (Get-PropertyValue $packagesById[$dependencyId] "fleet") "wave") "value"
            Add-Check ($wave -gt $dependencyWave) "$Context package '$packageId' is advertised in wave $wave before dependency '$dependencyId' in wave $dependencyWave is complete."
        }
    }

    $phasesById = @{}
    foreach ($phase in $Phases) {
        $phasesById[(Get-PropertyValue $phase "id")] = $phase
    }
    foreach ($phase in $Phases) {
        $phasePackageIds = @(Get-PropertyValue $phase "workPackageIds")
        foreach ($dependencyPhaseId in @(Get-PropertyValue $phase "dependsOnPhaseIds")) {
            if (-not $phasesById.ContainsKey($dependencyPhaseId)) {
                continue
            }
            $dependencyPhase = $phasesById[$dependencyPhaseId]
            if (-not (Get-PropertyValue $dependencyPhase "integrationCheckpoint")) {
                continue
            }
            $dependencyWaves = @(
                @(Get-PropertyValue $dependencyPhase "workPackageIds") |
                    ForEach-Object {
                        Get-PropertyValue (Get-PropertyValue (Get-PropertyValue $packagesById[$_] "fleet") "wave") "value"
                    }
            )
            $barrierWave = ($dependencyWaves | Measure-Object -Maximum).Maximum
            foreach ($packageId in $phasePackageIds) {
                $packageWave = Get-PropertyValue (Get-PropertyValue (Get-PropertyValue $packagesById[$packageId] "fleet") "wave") "value"
                Add-Check ($packageWave -gt $barrierWave) "$Context package '$packageId' in wave $packageWave crosses unreconciled checkpoint '$dependencyPhaseId' ending in wave $barrierWave."
            }
        }
    }

    $parallelPackages = @($WorkPackages | Where-Object {
        (Get-PropertyValue (Get-PropertyValue $_ "fleet") "suitability") -eq "eligible"
    })
    for ($leftIndex = 0; $leftIndex -lt $parallelPackages.Count; $leftIndex++) {
        for ($rightIndex = $leftIndex + 1; $rightIndex -lt $parallelPackages.Count; $rightIndex++) {
            $left = $parallelPackages[$leftIndex]
            $right = $parallelPackages[$rightIndex]
            $leftFleet = Get-PropertyValue $left "fleet"
            $rightFleet = Get-PropertyValue $right "fleet"
            $leftWave = Get-PropertyValue (Get-PropertyValue $leftFleet "wave") "value"
            $rightWave = Get-PropertyValue (Get-PropertyValue $rightFleet "wave") "value"
            $leftGroup = Get-PropertyValue (Get-PropertyValue $leftFleet "parallelGroup") "value"
            $rightGroup = Get-PropertyValue (Get-PropertyValue $rightFleet "parallelGroup") "value"
            if ($leftWave -ne $rightWave -or $leftGroup -ne $rightGroup) {
                continue
            }
            $leftWrites = @(
                @(Get-PropertyValue $leftFleet "fileOwnership") |
                    Where-Object { (Get-PropertyValue $_ "mode") -eq "exclusive-write" } |
                    ForEach-Object { Get-PropertyValue $_ "path" }
            )
            $rightWrites = @(
                @(Get-PropertyValue $rightFleet "fileOwnership") |
                    Where-Object { (Get-PropertyValue $_ "mode") -eq "exclusive-write" } |
                    ForEach-Object { Get-PropertyValue $_ "path" }
            )
            foreach ($leftPath in $leftWrites) {
                foreach ($rightPath in $rightWrites) {
                    Add-Check (-not (Test-PathsOverlap $leftPath $rightPath)) "$Context parallel packages '$((Get-PropertyValue $left "id"))' and '$((Get-PropertyValue $right "id"))' overlap at '$leftPath' and '$rightPath'."
                }
            }
        }
    }
}

Write-Host "Validating plugin at $pluginRoot"

Write-Host " - JSON and manifests"
$allJsonFiles = @(
    Get-Item -LiteralPath $marketplacePath
    Get-Item -LiteralPath $repositoryPluginManifestPath
    Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Filter "*.json"
)
$jsonDocuments = @{}
foreach ($jsonFile in $allJsonFiles) {
    $jsonDocuments[$jsonFile.FullName] = Read-JsonFile $jsonFile.FullName
}
Add-Check ($script:Failures.Count -eq 0) "One or more JSON files could not be parsed."

$marketplace = $jsonDocuments[$marketplacePath]
$repositoryPlugin = $jsonDocuments[$repositoryPluginManifestPath]
$plugin = $jsonDocuments[$pluginManifestPath]
Test-AllowedProperties $marketplace @("name", "metadata", "owner", "plugins") "Marketplace manifest"
Test-AllowedProperties (Get-PropertyValue $marketplace "metadata") @("description", "version") "Marketplace metadata"
Test-AllowedProperties (Get-PropertyValue $marketplace "owner") @("name", "email") "Marketplace owner"
Add-Check ((Get-PropertyValue $marketplace "name") -match "^[a-z0-9]+(?:-[a-z0-9]+)*$") "Marketplace name is missing or invalid."
Add-Check ((Get-PropertyValue (Get-PropertyValue $marketplace "metadata") "version") -match "^\d+\.\d+\.\d+$") "Marketplace version is not semantic."

Test-AllowedProperties $plugin @(
    '$schema', "name", "description", "version", "author", "homepage",
    "repository", "license", "keywords", "category", "tags", "skills",
    "agents", "commands", "hooks", "extensions", "mcpServers", "lspServers"
) "Plugin manifest"
Test-AllowedProperties $repositoryPlugin @(
    '$schema', "name", "description", "version", "author", "homepage",
    "repository", "license", "keywords", "category", "tags", "skills",
    "agents", "commands", "hooks", "extensions", "mcpServers", "lspServers"
) "Repository plugin manifest"
Test-AllowedProperties (Get-PropertyValue $plugin "author") @("name", "email", "url") "Plugin author"
Test-AllowedProperties (Get-PropertyValue $repositoryPlugin "author") @("name", "email", "url") "Repository plugin author"
Add-Check ((Get-PropertyValue $plugin "name") -match "^[a-z0-9]+(?:-[a-z0-9]+)*$") "Plugin name is missing or invalid."
Add-Check ((Get-PropertyValue $plugin "version") -match "^\d+\.\d+\.\d+$") "Plugin version is not semantic."
foreach ($property in @("name", "description", "version")) {
    Add-Check (
        (Get-PropertyValue $repositoryPlugin $property) -eq (Get-PropertyValue $plugin $property)
    ) "Repository and marketplace plugin manifests differ on '$property'."
}

$marketplacePlugins = @(Get-PropertyValue $marketplace "plugins")
Add-Check ($marketplacePlugins.Count -gt 0) "Marketplace has no plugins."
foreach ($entry in $marketplacePlugins) {
    Test-AllowedProperties $entry @("name", "description", "version", "source") "Marketplace plugin entry"
    $source = Get-PropertyValue $entry "source"
    $sourcePath = Resolve-ComponentPath $repoRoot $source
    Add-Check (Test-Path -LiteralPath $sourcePath -PathType Container) "Marketplace source '$source' does not resolve."
    Add-Check ((Get-PropertyValue $entry "name") -eq (Get-PropertyValue $plugin "name")) "Marketplace and plugin names differ."
    Add-Check ((Get-PropertyValue $entry "version") -eq (Get-PropertyValue $plugin "version")) "Marketplace and plugin versions differ."
}

$skillsPath = Resolve-ComponentPath $pluginRoot (Get-PropertyValue $plugin "skills")
$agentsPath = Resolve-ComponentPath $pluginRoot (Get-PropertyValue $plugin "agents")
$repositorySkillsPath = Resolve-ComponentPath $repoRoot (Get-PropertyValue $repositoryPlugin "skills")
$repositoryAgentsPath = Resolve-ComponentPath $repoRoot (Get-PropertyValue $repositoryPlugin "agents")
Add-Check (Test-Path -LiteralPath $skillsPath -PathType Container) "Plugin skills directory is missing."
Add-Check (Test-Path -LiteralPath $agentsPath -PathType Container) "Plugin agents directory is missing."
Add-Check (Test-Path -LiteralPath $repositorySkillsPath -PathType Container) "Repository plugin skills directory is missing."
Add-Check (Test-Path -LiteralPath $repositoryAgentsPath -PathType Container) "Repository plugin agents directory is missing."
Add-Check ($repositorySkillsPath -eq $skillsPath) "Repository and marketplace plugin manifests resolve different skills directories."
Add-Check ($repositoryAgentsPath -eq $agentsPath) "Repository and marketplace plugin manifests resolve different agents directories."

$skillFiles = @(Get-ChildItem -LiteralPath $skillsPath -Recurse -File -Filter "SKILL.md")
$agentFiles = @(Get-ChildItem -LiteralPath $agentsPath -File -Filter "*.agent.md")
Add-Check ($skillFiles.Count -gt 0) "No skills were discovered from plugin.json."
Add-Check ($agentFiles.Count -gt 0) "No agents were discovered from plugin.json."
Add-Check ($agentFiles.Count -eq 9) "Expected 9 plugin agents, found $($agentFiles.Count)."
foreach ($requiredAgent in @(
    "wcf-migration-orchestrator.agent.md",
    "wcf-codebase-analyst.agent.md",
    "wcf-migration-decision-interviewer.agent.md",
    "wcf-to-grpc-mapper.agent.md",
    "grpc-migration-architect.agent.md",
    "grpc-migration-issue-publisher.agent.md",
    "grpc-migration-implementer.agent.md",
    "grpc-code-handoff-author.agent.md",
    "grpc-parity-validator.agent.md"
)) {
    Add-Check ($agentFiles.Name -contains $requiredAgent) "Required plugin agent '$requiredAgent' is missing."
}

$skillNames = @()
foreach ($skillFile in $skillFiles) {
    $frontmatter = Read-Frontmatter $skillFile.FullName
    foreach ($key in $frontmatter.Keys) {
        Add-Check ($key -in @("name", "description", "license", "allowed-tools")) "Skill $($skillFile.FullName) has unsupported frontmatter field '$key'."
    }
    Add-Check ($frontmatter.ContainsKey("name")) "Skill $($skillFile.FullName) is missing frontmatter name."
    Add-Check ($frontmatter.ContainsKey("description")) "Skill $($skillFile.FullName) is missing frontmatter description."
    if ($frontmatter.ContainsKey("name")) {
        $skillNames += $frontmatter["name"]
        Add-Check ($frontmatter["name"] -eq $skillFile.Directory.Name) "Skill name '$($frontmatter["name"])' does not match directory '$($skillFile.Directory.Name)'."
        Add-Check ($frontmatter["name"].Length -le 64) "Skill name '$($frontmatter["name"])' exceeds 64 characters."
    }
    if ($frontmatter.ContainsKey("description")) {
        Add-Check (-not [string]::IsNullOrWhiteSpace($frontmatter["description"])) "Skill $($skillFile.FullName) has an empty description."
        Add-Check ($frontmatter["description"].Length -le 1024) "Skill $($skillFile.FullName) description exceeds 1024 characters."
    }
}
foreach ($duplicate in $skillNames | Group-Object | Where-Object Count -gt 1) {
    Add-Check $false "Duplicate skill name '$($duplicate.Name)'."
}

$agentNames = @()
foreach ($agentFile in $agentFiles) {
    $frontmatter = Read-Frontmatter $agentFile.FullName
    foreach ($key in $frontmatter.Keys) {
        Add-Check ($key -in @(
            "name", "description", "target", "tools", "model",
            "disable-model-invocation", "user-invocable", "mcp-servers", "metadata"
        )) "Agent $($agentFile.FullName) has unsupported frontmatter field '$key'."
    }
    foreach ($required in @("name", "description")) {
        Add-Check ($frontmatter.ContainsKey($required)) "Agent $($agentFile.FullName) is missing frontmatter $required."
    }
    if ($frontmatter.ContainsKey("name")) {
        $agentNames += $frontmatter["name"]
        Add-Check ($frontmatter["name"].Length -le 64) "Agent name '$($frontmatter["name"])' exceeds 64 characters."
    }
    if ($frontmatter.ContainsKey("description")) {
        Add-Check (-not [string]::IsNullOrWhiteSpace($frontmatter["description"])) "Agent $($agentFile.FullName) has an empty description."
        Add-Check ($frontmatter["description"].Length -le 1024) "Agent $($agentFile.FullName) description exceeds 1024 characters."
    }
    foreach ($booleanKey in @("disable-model-invocation", "user-invocable")) {
        if ($frontmatter.ContainsKey($booleanKey)) {
            Add-Check ($frontmatter[$booleanKey] -in @("true", "false")) "Agent $($agentFile.FullName) frontmatter '$booleanKey' must be true or false."
        }
    }
    $agentPromptLength = (Get-Content -LiteralPath $agentFile.FullName -Raw).Length
    Add-Check ($agentPromptLength -le 30000) "Agent $($agentFile.FullName) exceeds the 30,000-character prompt limit."
}
foreach ($duplicate in $agentNames | Group-Object | Where-Object Count -gt 1) {
    Add-Check $false "Duplicate agent name '$($duplicate.Name)'."
}

Write-Host " - documentation coverage"
$pluginReadmePath = Join-Path $pluginRoot "README.md"
$repoReadmePath = Join-Path $repoRoot "README.md"
Add-Check (Test-Path -LiteralPath $pluginReadmePath -PathType Leaf) "Plugin README.md is missing."
Add-Check (Test-Path -LiteralPath $repoReadmePath -PathType Leaf) "Repository README.md is missing."
Add-Check (Test-Path -LiteralPath $docsRoot -PathType Container) "Repository docs directory is missing."

foreach ($requiredDoc in @("architecture.md", "migration-methodology.md", "output-contracts.md", "contributing.md")) {
    Add-Check (Test-Path -LiteralPath (Join-Path $docsRoot $requiredDoc) -PathType Leaf) "Required documentation file docs/$requiredDoc is missing."
}

if ((Test-Path -LiteralPath $pluginReadmePath -PathType Leaf) -and (Test-Path -LiteralPath $repoReadmePath -PathType Leaf)) {
    $pluginReadme = Get-Content -LiteralPath $pluginReadmePath -Raw
    $repoReadme = Get-Content -LiteralPath $repoReadmePath -Raw
    foreach ($agentFile in $agentFiles) {
        Add-Check ($pluginReadme -like "*$($agentFile.Name)*") "Plugin README does not document agent '$($agentFile.Name)'."
        Add-Check ($repoReadme -like "*$($agentFile.Name)*") "Repository README does not document agent '$($agentFile.Name)'."
    }

    $interviewerPath = Join-Path $agentsPath "wcf-migration-decision-interviewer.agent.md"
    $orchestratorPath = Join-Path $agentsPath "wcf-migration-orchestrator.agent.md"
    $architectPath = Join-Path $agentsPath "grpc-migration-architect.agent.md"
    $parityValidatorPath = Join-Path $agentsPath "grpc-parity-validator.agent.md"
    $handoffAuthorPath = Join-Path $agentsPath "grpc-code-handoff-author.agent.md"
    $issuePublisherPath = Join-Path $agentsPath "grpc-migration-issue-publisher.agent.md"
    $catalogPath = Join-Path $pluginRoot "skills/interview-migration-decisions/references/question-catalog.md"
    foreach ($requiredText in @("prepare-draft", "resolve-blocker", "record-bundle-approval", "partial-draft-ready", "ready-for-draft")) {
        Add-Check ((Get-Content -LiteralPath $interviewerPath -Raw) -like "*$requiredText*") "Decision interviewer is missing '$requiredText' workflow guidance."
    }
    foreach ($requiredClass in @("agent-proposed", "review-required", "immediate-answer-required", "deferred-operational", "out-of-scope-handoff")) {
        Add-Check ((Get-Content -LiteralPath $catalogPath -Raw) -like "*$requiredClass*") "Question catalog is missing '$requiredClass'."
    }
    Add-Check ((Get-Content -LiteralPath $architectPath -Raw) -like "*migration-review.schema.json*") "Architect does not reference the migration-review schema."
    Add-Check ((Get-Content -LiteralPath $orchestratorPath -Raw) -like "*record-bundle-approval*") "Orchestrator does not coordinate bundle decision approval."
    $orchestratorText = Get-Content -LiteralPath $orchestratorPath -Raw
    Add-Check ($orchestratorText -like "*only external mutation*") "Orchestrator does not preserve Issue publication as the only external mutation."
    Add-Check ($orchestratorText -notmatch "grpc-parity-validator") "Code-only orchestrator must never dispatch or depend on the parity validator."
    Add-Check ($orchestratorText -notmatch "allowHarness|allowGoldenTraffic|allowLoadTest|allowProductionAccess") "Code-only orchestrator still declares an operational permission."
    Add-Check ($orchestratorText -like "*code-complete*" -and $orchestratorText -like "*offline handoff*") "Orchestrator lacks its code-complete terminal handoff."
    Add-Check ((Get-Content -LiteralPath $parityValidatorPath -Raw) -like "*never dispatched by the migration orchestrator*") "Parity validator is not clearly documented as manual-only."
    Add-Check ((Get-Content -LiteralPath $handoffAuthorPath -Raw) -like "*never changes product code*") "Code handoff author lacks its read-only product boundary."
    $issuePublisherText = Get-Content -LiteralPath $issuePublisherPath -Raw
    Add-Check ($issuePublisherText -like "*previewDigest*" -and $issuePublisherText -like "*publish-approved*") "Optional Issue publication no longer requires digest-bound confirmation."
    $digestScriptPath = Join-Path $pluginRoot "scripts/Semantic-Digest.ps1"
    $digestNodeScriptPath = Join-Path $pluginRoot "scripts/Semantic-Digest.mjs"
    $digestRulesPath = Join-Path $pluginRoot "scripts/semantic-digest-rules.v1.json"
    $artifactValidatorPath = Join-Path $pluginRoot "scripts/Validate-Artifact.ps1"
    $artifactSemanticValidatorPath = Join-Path $pluginRoot "scripts/Test-ArtifactSemantics.ps1"
    $reviewValidatorPath = Join-Path $pluginRoot "scripts/Validate-Review-Markdown.ps1"
    $handoffMarkdownValidatorPath = Join-Path $pluginRoot "scripts/Validate-Handoff-Markdown.ps1"
    Add-Check (Test-Path -LiteralPath $digestScriptPath -PathType Leaf) "Shared semantic digest utility is missing."
    Add-Check (Test-Path -LiteralPath $digestNodeScriptPath -PathType Leaf) "Node semantic digest utility is missing."
    Add-Check (Test-Path -LiteralPath $digestRulesPath -PathType Leaf) "Versioned semantic digest rules are missing."
    Add-Check (Test-Path -LiteralPath $artifactValidatorPath -PathType Leaf) "Runtime artifact validator is missing."
    Add-Check (Test-Path -LiteralPath $artifactSemanticValidatorPath -PathType Leaf) "Artifact semantic validator is missing."
    Add-Check (Test-Path -LiteralPath $reviewValidatorPath -PathType Leaf) "Review Markdown consistency validator is missing."
    Add-Check (Test-Path -LiteralPath $handoffMarkdownValidatorPath -PathType Leaf) "Handoff Markdown consistency validator is missing."
    if ((Test-Path -LiteralPath $digestScriptPath -PathType Leaf) -and
        (Test-Path -LiteralPath $digestRulesPath -PathType Leaf)) {
        try {
            $digestFixture = Join-Path $fixtureRoot "semantic-digest-lifecycle.json"
            $digestResult = @(& $digestScriptPath self-test $digestFixture -RulesPath $digestRulesPath) -join "`n"
            Add-Check ($digestResult -match "^Self-test passed \(3 lifecycle cases; corpus sha256:[a-f0-9]{64}\)\.$") "PowerShell semantic digest lifecycle and corpus self-test did not pass."
            $nodeDigestResult = @(& node $digestNodeScriptPath self-test $digestFixture --rules $digestRulesPath) -join "`n"
            Add-Check ($LASTEXITCODE -eq 0) "Node semantic digest lifecycle and corpus self-test did not pass."
            Add-Check ($nodeDigestResult -ceq $digestResult) "PowerShell and Node semantic digest canonicalization are not byte-equivalent."
        }
        catch {
            Add-Check $false "Semantic digest lifecycle self-test failed: $($_.Exception.Message)"
        }
    }
    $reviewTemplateText = Get-Content -LiteralPath (Join-Path $pluginRoot "skills/author-migration-specs/templates/migration-review.md") -Raw
    Add-Check ($reviewTemplateText -like "*{{approval.state}}*") "Migration review template does not render lifecycle state from structured approval data."
    Add-Check ($reviewTemplateText -notlike "*This review approves only*") "Migration review template contains stale static approval prose."

    $orchestrationSchemaText = Get-Content -LiteralPath (Join-Path $pluginRoot "schemas/orchestration-state.schema.json") -Raw
    Add-Check ($orchestrationSchemaText -notmatch '"validationRuns"|"retirementOutcome"|"allowHarness"|"allowGoldenTraffic"|"allowLoadTest"|"allowProductionAccess"') "Orchestration state still stores removed operational gates or outcomes."
    Add-Check ($orchestrationSchemaText -like '*"code-complete"*' -and $orchestrationSchemaText -like '*"offline-handoff"*') "Orchestration state lacks code-only completion stages."
    Add-Check ($orchestrationSchemaText -like '*"capabilityCheck"*' -and $orchestrationSchemaText -like '*"attemptHistory"*') "Orchestration state lacks capability preflight or append-only attempt history."
    Add-Check ($orchestratorText -like "*capability-probe*" -and $orchestratorText -like "*do not retry*") "Orchestrator does not reject unchanged incapable implementation backends."
    $architectText = Get-Content -LiteralPath $architectPath -Raw
    Add-Check ($architectText -like "*approvalTransaction*" -and $architectText -like "*implementation*require*a new*design choice*") "Architect lacks atomic approval or implementation-readiness safeguards."
    $implementerText = Get-Content -LiteralPath (Join-Path $agentsPath "grpc-migration-implementer.agent.md") -Raw
    Add-Check ($implementerText -like "*capability-probe*" -and $implementerText -like "*wcf-protected*") "Implementer lacks execution capability or immutable-WCF preflight."
    $inventorySchemaText = Get-Content -LiteralPath (Join-Path $pluginRoot "schemas/inventory.schema.json") -Raw
    Add-Check ($inventorySchemaText -like '*"blocksGates"*' -and $inventorySchemaText -notlike '*"blocking"*') "Inventory unknowns are not modeled by exact migration gates."

    $streamliningFixturePath = Join-Path $fixtureRoot "decision-streamlining.json"
    $streamliningFixture = $jsonDocuments[$streamliningFixturePath]
    $streamliningGroups = @(
        @(Get-PropertyValue $streamliningFixture "bundledForReview"),
        @(Get-PropertyValue $streamliningFixture "immediateOnlyIfEvidenceCannotSupportPreservation"),
        @(Get-PropertyValue $streamliningFixture "deferredCodeInputs"),
        @(Get-PropertyValue $streamliningFixture "outOfScopeHandoff")
    )
    $streamliningIds = @($streamliningGroups | ForEach-Object { $_ })
    Add-Check ((Get-PropertyValue $streamliningFixture "totalDecisions") -eq 40) "Decision streamlining regression fixture must cover 40 decisions."
    Add-Check ($streamliningIds.Count -eq 40) "Decision streamlining groups must contain all 40 decisions."
    Add-Check (($streamliningIds | Sort-Object -Unique).Count -eq 40) "Decision streamlining groups contain duplicate decision IDs."
    $nonInterruptingDecisionCount =
        @(Get-PropertyValue $streamliningFixture "bundledForReview").Count +
        @(Get-PropertyValue $streamliningFixture "deferredCodeInputs").Count +
        @(Get-PropertyValue $streamliningFixture "outOfScopeHandoff").Count
    Add-Check ($nonInterruptingDecisionCount -ge 35) "Decision streamlining fixture must avoid individual prompts for safe defaults and offline handoff topics."
    Add-Check ((Get-PropertyValue $streamliningFixture "expectedMaximumImmediatePrompts") -le 4) "Decision streamlining fixture permits too many immediate prompts."
    Add-Check (@(Get-PropertyValue $streamliningFixture "outOfScopeHandoff").Count -ge 10) "Deployment-era decisions were not moved to the offline handoff."
    $immediateDecisionIds = @(Get-PropertyValue $streamliningFixture "immediateOnlyIfEvidenceCannotSupportPreservation")
    Add-Check ($immediateDecisionIds.Count -le (Get-PropertyValue $streamliningFixture "expectedMaximumImmediatePrompts")) "Decision streamlining fixture exceeds its immediate-prompt limit."
    $expectedImmediateIds = @("DEC-audit-requirements", "DEC-state-concurrency", "DEC-state-lifetime", "DEC-state-storage")
    Add-Check (@(Compare-Object ($immediateDecisionIds | Sort-Object) ($expectedImmediateIds | Sort-Object)).Count -eq 0) "Decision streamlining fixture changed the authoritative immediate-decision set."
    $expectedStreamliningIds = @(
        "DEC-audit-requirements", "DEC-authorization-policy", "DEC-baseline-source",
        "DEC-capacity-scaling", "DEC-certificate-operations", "DEC-coexistence-exit-gates",
        "DEC-compatibility-policy", "DEC-configuration-ownership", "DEC-cutover-gates",
        "DEC-cutover-unit", "DEC-deadline-policy", "DEC-deployment-strategy",
        "DEC-error-disclosure", "DEC-external-consumer-support", "DEC-fault-status-map",
        "DEC-golden-traffic", "DEC-hosting-model", "DEC-http-coexistence-strategy",
        "DEC-identity-provider", "DEC-operating-system", "DEC-package-versioning",
        "DEC-parity-oracle", "DEC-payload-limit-policy", "DEC-payload-logging",
        "DEC-presence-semantics", "DEC-proto-ownership", "DEC-retirement-approval",
        "DEC-retry-policy", "DEC-rollback-data", "DEC-rollback-trigger",
        "DEC-service-authentication", "DEC-service-discovery", "DEC-sla-objectives",
        "DEC-state-concurrency", "DEC-state-lifetime", "DEC-state-storage",
        "DEC-target-runtime", "DEC-telemetry-standard", "DEC-test-environments",
        "DEC-transport-security"
    )
    Add-Check (@(Compare-Object ($streamliningIds | Sort-Object) ($expectedStreamliningIds | Sort-Object)).Count -eq 0) "Decision streamlining fixture does not match the authoritative 40-decision sample."

    $codeOnlyFixturePath = Join-Path $fixtureRoot "code-only-workflow.json"
    $codeOnlyFixture = $jsonDocuments[$codeOnlyFixturePath]
    $expectedStages = @(
        "intake", "inventory", "decision-preparation", "mapping",
        "specification", "consolidated-review", "publication", "implementation",
        "final-local-checkpoint", "offline-handoff"
    )
    Add-Check (@(Compare-Object (@(Get-PropertyValue $codeOnlyFixture "stages") | Sort-Object) ($expectedStages | Sort-Object)).Count -eq 0) "Code-only fixture stage sequence is incomplete."
    Add-Check (@(Get-PropertyValue $codeOnlyFixture "permissions").Count -eq 2) "Code-only fixture must expose only network and optional GitHub mutation permissions."
    Add-Check ((Get-PropertyValue $codeOnlyFixture "terminalOutcome") -eq "code-complete") "Code-only fixture has the wrong terminal outcome."
    Add-Check ((Get-PropertyValue (Get-PropertyValue $codeOnlyFixture "finalWorkPackage") "kind") -eq "final-local-verification") "Code-only fixture lacks a final local verification package."
    $expectedSolutionLayouts = @(
        "augment-existing-solution",
        "isolated-new-solution-reference-wcf",
        "isolated-new-solution-copy-wcf-fixture",
        "isolated-new-solution-grpc-only"
    )
    Add-Check (@(Compare-Object (@(Get-PropertyValue $codeOnlyFixture "solutionLayouts") | Sort-Object) ($expectedSolutionLayouts | Sort-Object)).Count -eq 0) "Code-only fixture does not enumerate every solution layout."
    Add-Check (@(Get-PropertyValue $codeOnlyFixture "isolatedLayoutRules").Count -eq 5) "Code-only fixture does not enumerate the isolated-layout safety rules."
    Add-Check (@(Get-PropertyValue $codeOnlyFixture "offlineCategories").Count -ge 10) "Code-only fixture does not cover the offline handoff."
    Add-Check (@(Get-PropertyValue $codeOnlyFixture "forbiddenOrchestratedActions").Count -eq 8) "Code-only fixture does not enumerate every forbidden operational action."
    foreach ($skillFile in $skillFiles) {
        $skillReference = "skills/$($skillFile.Directory.Name)/"
        Add-Check ($pluginReadme -like "*$skillReference*") "Plugin README does not document skill '$($skillFile.Directory.Name)'."
        Add-Check ($repoReadme -like "*$skillReference*") "Repository README does not document skill '$($skillFile.Directory.Name)'."
    }
}

$placeholderFiles = @(
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force -Filter ".gitkeep" -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force -Filter ".gitkeep.*" -ErrorAction SilentlyContinue
)
foreach ($placeholderFile in $placeholderFiles) {
    Add-Check $false "Placeholder file '$($placeholderFile.FullName)' must be removed."
}

Write-Host " - schemas and examples"
$schemaFiles = @(Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Filter "*.schema.json")
foreach ($schemaFile in $schemaFiles) {
    $schema = $jsonDocuments[$schemaFile.FullName]
    Add-Check ((Get-PropertyValue $schema '$schema') -eq "https://json-schema.org/draft/2020-12/schema") "Schema $($schemaFile.FullName) is not Draft 2020-12."
    Add-Check (-not [string]::IsNullOrWhiteSpace((Get-PropertyValue $schema '$id'))) "Schema $($schemaFile.FullName) has no `$id."

    $rawSchema = Get-Content -LiteralPath $schemaFile.FullName -Raw
    foreach ($match in [regex]::Matches($rawSchema, '"\$ref"\s*:\s*"([^"]+)"')) {
        $reference = $match.Groups[1].Value
        $hashIndex = $reference.IndexOf("#")
        if ($hashIndex -ge 0) {
            $referencePath = $reference.Substring(0, $hashIndex)
            $fragment = $reference.Substring($hashIndex)
        }
        else {
            $referencePath = $reference
            $fragment = ""
        }

        if ([string]::IsNullOrEmpty($referencePath)) {
            $targetPath = $schemaFile.FullName
        }
        else {
            $targetPath = Resolve-ComponentPath $schemaFile.Directory.FullName $referencePath
        }

        Add-Check (Test-Path -LiteralPath $targetPath -PathType Leaf) "Schema reference '$reference' in $($schemaFile.FullName) has no target file."
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            if (-not $jsonDocuments.ContainsKey($targetPath)) {
                $jsonDocuments[$targetPath] = Read-JsonFile $targetPath
            }
            Add-Check (Resolve-JsonPointer $jsonDocuments[$targetPath] $fragment) "Schema reference '$reference' in $($schemaFile.FullName) has no target fragment."
        }
    }
}

$schemaValidationPairs = @(
    @{
        Json = Join-Path $pluginRoot "skills/author-migration-specs/examples/migration-spec.example.json"
        Schema = Join-Path $pluginRoot "schemas/migration-spec.schema.json"
    },
    @{
        Json = Join-Path $pluginRoot "skills/author-migration-specs/examples/migration-review.example.json"
        Schema = Join-Path $pluginRoot "schemas/migration-review.schema.json"
    },
    @{
        Json = Join-Path $pluginRoot "skills/publish-migration-issues/examples/issue-set.example.json"
        Schema = Join-Path $pluginRoot "schemas/issue-set.schema.json"
    },
    @{
        Json = Join-Path $pluginRoot "skills/map-wcf-to-grpc/examples/mapping-result.example.json"
        Schema = Join-Path $pluginRoot "schemas/mapping-result.schema.json"
    },
    @{
        Json = Join-Path $pluginRoot "skills/finalize-code-handoff/examples/code-handoff.example.json"
        Schema = Join-Path $pluginRoot "schemas/code-handoff.schema.json"
    },
    @{
        Json = Join-Path $fixtureRoot "orchestration-state-code-complete.json"
        Schema = Join-Path $pluginRoot "schemas/orchestration-state.schema.json"
    }
)
foreach ($expectedFile in Get-ChildItem -LiteralPath $fixtureRoot -Recurse -File -Filter "expected.json") {
    $schemaValidationPairs += @{
        Json = $expectedFile.FullName
        Schema = $fixtureSchemaPath
    }
}
foreach ($pair in $schemaValidationPairs) {
    try {
        Add-Check (Test-Json -LiteralPath $pair.Json -SchemaFile $pair.Schema -ErrorAction Stop) "JSON artifact $($pair.Json) does not conform to $($pair.Schema)."
    }

    catch {
        Add-Check $false "Could not schema-validate $($pair.Json): $($_.Exception.Message)"
    }
}

$migrationSpecExamplePath = Join-Path $pluginRoot "skills/author-migration-specs/examples/migration-spec.example.json"
$migrationSpecSchemaPath = Join-Path $pluginRoot "schemas/migration-spec.schema.json"
try {
    $artifactValidation = @(
        & $artifactValidatorPath -ArtifactPath $migrationSpecExamplePath -SchemaPath $migrationSpecSchemaPath
    ) -join "`n" | ConvertFrom-Json
    Add-Check ($artifactValidation.valid -and $artifactValidation.semanticValidation.semanticValid) "Migration-spec example did not pass schema and semantic validation."
}
catch {
    Add-Check $false "Migration-spec example semantic validation failed: $($_.Exception.Message)"
}

try {
    $handoffJsonExample = Join-Path $pluginRoot "skills/finalize-code-handoff/examples/code-handoff.example.json"
    $handoffMarkdownExample = Join-Path $pluginRoot "skills/finalize-code-handoff/examples/code-handoff.example.md"
    $handoffConsistency = @(
        & $handoffMarkdownValidatorPath -HandoffJsonPath $handoffJsonExample -HandoffMarkdownPath $handoffMarkdownExample
    ) -join "`n" | ConvertFrom-Json
    Add-Check ($handoffConsistency.consistent) "Code-handoff JSON and Markdown examples are inconsistent."
}
catch {
    Add-Check $false "Code-handoff Markdown consistency validation failed: $($_.Exception.Message)"
}

try {
    $reviewJsonExample = Join-Path $pluginRoot "skills/author-migration-specs/examples/migration-review.example.json"
    $reviewMarkdownExample = Join-Path $pluginRoot "skills/author-migration-specs/examples/migration-review.example.md"
    $reviewConsistency = @(
        & $reviewValidatorPath -ReviewJsonPath $reviewJsonExample -ReviewMarkdownPath $reviewMarkdownExample
    ) -join "`n" | ConvertFrom-Json
    Add-Check ($reviewConsistency.consistent) "Migration-review JSON and Markdown examples are inconsistent."
}
catch {
    Add-Check $false "Migration-review Markdown consistency validation failed: $($_.Exception.Message)"
}

try {
    $reviewValidation = @(
        & $artifactValidatorPath -ArtifactPath $reviewJsonExample -SchemaPath (Join-Path $pluginRoot "schemas/migration-review.schema.json")
    ) -join "`n" | ConvertFrom-Json
    Add-Check ($reviewValidation.valid -and $reviewValidation.semanticValidation.semanticValid) "Migration-review example did not pass schema and semantic validation."
}
catch {
    Add-Check $false "Migration-review example semantic validation failed: $($_.Exception.Message)"
}

$invalidSemanticFixture = New-TemporaryFile
try {
    $invalidSpec = Get-Content -LiteralPath $migrationSpecExamplePath -Raw | ConvertFrom-Json -Depth 100
    $invalidSpec.contracts[0].messages[0].fields[1].number =
        $invalidSpec.contracts[0].messages[0].fields[0].number
    $invalidSpec | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $invalidSemanticFixture
    $invalidResult = @(& $artifactSemanticValidatorPath -ArtifactPath $invalidSemanticFixture) -join "`n" | ConvertFrom-Json
    Add-Check (-not $invalidResult.semanticValid -and
        @($invalidResult.errors | Where-Object { $_ -like "*reuses field number*" }).Count -gt 0) "Artifact semantic validator did not reject duplicate Protobuf field numbers."
}
catch {
    Add-Check $false "Could not exercise invalid artifact semantic fixture: $($_.Exception.Message)"
}
finally {
    Remove-Item -LiteralPath $invalidSemanticFixture -Force -ErrorAction SilentlyContinue
}

$orchestrationSchemaPath = Join-Path $pluginRoot "schemas/orchestration-state.schema.json"
$orchestrationFixturePath = Join-Path $fixtureRoot "orchestration-state-code-complete.json"
$layoutCases = @(
    @{
        Mode = "isolated-new-solution-reference-wcf"
        Handling = "reference-original-readonly"
        CopyRoot = @{ state = "not-applicable"; reason = "Original WCF projects are referenced read-only." }
    },
    @{
        Mode = "isolated-new-solution-copy-wcf-fixture"
        Handling = "copy-immutable-test-fixture"
        CopyRoot = @{ state = "known"; value = "test-fixtures/wcf" }
    },
    @{
        Mode = "isolated-new-solution-grpc-only"
        Handling = "external-only"
        CopyRoot = @{ state = "not-applicable"; reason = "The isolated solution contains no WCF source." }
    }
)
foreach ($layoutCase in $layoutCases) {
    $layoutFixture = Get-Content -LiteralPath $orchestrationFixturePath -Raw | ConvertFrom-Json
    $layoutFixture.solutionLayout.mode = $layoutCase.Mode
    $layoutFixture.solutionLayout.grpcRoot = "grpc-migration"
    $layoutFixture.solutionLayout.originalSolutionMutationAllowed = $false
    $layoutFixture.solutionLayout.wcfSourceHandling = $layoutCase.Handling
    $layoutFixture.solutionLayout.copiedWcfFixtureRoot = $layoutCase.CopyRoot
    Add-Check (
        Test-Json -Json ($layoutFixture | ConvertTo-Json -Depth 100) -SchemaFile $orchestrationSchemaPath -ErrorAction SilentlyContinue
    ) "Solution layout '$($layoutCase.Mode)' does not validate."
}

$invalidLayoutFixture = Get-Content -LiteralPath $orchestrationFixturePath -Raw | ConvertFrom-Json
$invalidLayoutFixture.solutionLayout.mode = "isolated-new-solution-reference-wcf"
$invalidLayoutFixture.solutionLayout.grpcRoot = "."
$invalidLayoutFixture.solutionLayout.originalSolutionMutationAllowed = $true
$invalidLayoutFixture.solutionLayout.wcfSourceHandling = "reference-original-readonly"
Add-Check (
    -not (Test-Json -Json ($invalidLayoutFixture | ConvertTo-Json -Depth 100) -SchemaFile $orchestrationSchemaPath -ErrorAction SilentlyContinue)
) "An isolated layout incorrectly permits repository-root writes or original-solution mutation."

$invalidCopyFixture = Get-Content -LiteralPath $orchestrationFixturePath -Raw | ConvertFrom-Json
$invalidCopyFixture.solutionLayout.mode = "isolated-new-solution-copy-wcf-fixture"
$invalidCopyFixture.solutionLayout.grpcRoot = "grpc-migration"
$invalidCopyFixture.solutionLayout.originalSolutionMutationAllowed = $false
$invalidCopyFixture.solutionLayout.wcfSourceHandling = "copy-immutable-test-fixture"
$invalidCopyFixture.solutionLayout.copiedWcfFixtureRoot = @{ state = "known"; value = "../wcf" }
Add-Check (
    -not (Test-Json -Json ($invalidCopyFixture | ConvertTo-Json -Depth 100) -SchemaFile $orchestrationSchemaPath -ErrorAction SilentlyContinue)
) "A copied WCF fixture incorrectly permits a path outside grpcRoot."

$stateLayout = Get-PropertyValue $jsonDocuments[$orchestrationFixturePath] "solutionLayout"
$specLayout = Get-PropertyValue $jsonDocuments[(Join-Path $pluginRoot "skills/author-migration-specs/examples/migration-spec.example.json")] "solutionLayout"
$handoffLayout = Get-PropertyValue $jsonDocuments[(Join-Path $pluginRoot "skills/finalize-code-handoff/examples/code-handoff.example.json")] "solutionLayout"
$stateLayoutJson = $stateLayout | ConvertTo-Json -Depth 20 -Compress
Add-Check (($specLayout | ConvertTo-Json -Depth 20 -Compress) -eq $stateLayoutJson) "Migration specification does not preserve the Stage 0 solution layout."
Add-Check (($handoffLayout | ConvertTo-Json -Depth 20 -Compress) -eq $stateLayoutJson) "Code handoff does not preserve the Stage 0 solution layout."

Write-Host " - stable IDs and dependency DAGs"
$artifactJsonFiles = @(
    Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Filter "*.json" |
        Where-Object {
            $_.FullName -match "[\\/]examples[\\/]" -or $_.Name -eq "expected.json"
        }
)
foreach ($artifactFile in $artifactJsonFiles) {
    $artifact = $jsonDocuments[$artifactFile.FullName]
    Test-StableIds $artifact $artifactFile.FullName

    $artifactType = Get-PropertyValue $artifact "artifactType"
    if ($artifactType -eq "migration-spec") {
        Test-DependencyDag @(Get-PropertyValue $artifact "workPackages") {
            param($node)
            foreach ($dependency in @(Get-PropertyValue $node "dependencies")) {
                Get-PropertyValue $dependency "workPackageId"
            }
        } "$($artifactFile.FullName) work packages"
        $workPackages = @(Get-PropertyValue $artifact "workPackages")
        Test-WavePlan $workPackages @((Get-PropertyValue (Get-PropertyValue $artifact "roadmap") "phases")) "$($artifactFile.FullName) fleet plan"
        Add-Check ($workPackages.Count -gt 0) "Migration specification has no code work packages."
        Add-Check ((Get-PropertyValue $artifact "digestAlgorithmVersion") -eq "sha256-rfc8785-v1") "Migration specification does not declare the shared digest algorithm."
        Add-Check ((Get-PropertyValue $artifact "wcfMutationPolicy") -eq "immutable") "Migration specification does not enforce immutable WCF."
        $readiness = Get-PropertyValue $artifact "implementationReadiness"
        Add-Check (-not [string]::IsNullOrWhiteSpace((Get-PropertyValue $readiness "sdkVersion"))) "Migration specification omits the exact SDK version."
        Add-Check (@(Get-PropertyValue $readiness "packageReferences").Count -gt 0) "Migration specification omits exact package references."
        foreach ($packageReference in @(Get-PropertyValue $readiness "packageReferences")) {
            $version = Get-PropertyValue $packageReference "version"
            Add-Check (-not [string]::IsNullOrWhiteSpace($version) -and $version -notmatch "[*xX]") "Migration specification contains an inexact package version for '$((Get-PropertyValue $packageReference "id"))'."
        }
        Add-Check (@($workPackages | Where-Object { (Get-PropertyValue $_ "kind") -eq "final-local-verification" }).Count -eq 1) "Migration specification must contain exactly one final local verification package."
        foreach ($workPackage in $workPackages) {
            Add-Check ((Get-PropertyValue $workPackage "semanticSubDigest") -match "^sha256:[a-f0-9]{64}$") "Work package '$((Get-PropertyValue $workPackage "id"))' lacks a semantic sub-digest."
            Add-Check ((Get-PropertyValue $workPackage "kind") -in @("code-implementation", "final-local-verification")) "Work package '$((Get-PropertyValue $workPackage "id"))' is not code-only."
            $executableSurface = [ordered]@{
                objective = Get-PropertyValue $workPackage "objective"
                scope = Get-PropertyValue $workPackage "scope"
                deliverables = Get-PropertyValue $workPackage "deliverables"
                acceptanceCriteria = Get-PropertyValue $workPackage "acceptanceCriteria"
                validation = Get-PropertyValue $workPackage "validation"
            }
            $packageText = $executableSurface | ConvertTo-Json -Depth 100
            Add-Check ($packageText -notmatch "(?i)deploy(?:ment)? manifest|infrastructure-as-code|traffic cutover|execute live rollback|disable WCF|remove WCF|retire WCF") "Work package '$((Get-PropertyValue $workPackage "id"))' contains an executable operational action."
        }
    }
    elseif ($artifactType -eq "code-handoff") {
        Add-Check ((Get-PropertyValue (Get-PropertyValue $artifact "codeCompletion") "status") -eq "code-complete") "Code handoff lacks code-complete status."
        Add-Check ((Get-PropertyValue $artifact "wcfState") -eq "active-and-unchanged") "Code handoff does not keep WCF active."
        $obligations = @(Get-PropertyValue $artifact "offlineObligations")
        Add-Check ($obligations.Count -ge 10) "Code handoff does not cover enough operational topics."
        $expectedOfflineCategories = @(
            "environment-configuration", "secrets", "deployment",
            "service-discovery", "identity-and-tls", "data-and-state",
            "external-dependencies", "observability-health-capacity",
            "environment-parity-validation", "consumer-cutover",
            "live-rollback", "wcf-retirement"
        )
        $actualOfflineCategories = @($obligations | ForEach-Object { Get-PropertyValue $_ "category" })
        Add-Check (@(Compare-Object ($actualOfflineCategories | Sort-Object -Unique) ($expectedOfflineCategories | Sort-Object)).Count -eq 0) "Code handoff does not cover the exact required offline categories."
        foreach ($obligation in $obligations) {
            Add-Check ((Get-PropertyValue $obligation "executionState") -eq "not-executed") "Offline obligation '$((Get-PropertyValue $obligation "id"))' was represented as executed."
        }
    }
    elseif ($artifactType -eq "issue-set") {
        Test-DependencyDag @(Get-PropertyValue $artifact "issues") {
            param($node)
            @(Get-PropertyValue $node "dependsOnIssueIds")
        } "$($artifactFile.FullName) issues"
    }
    elseif ($artifactFile.Name -eq "expected.json") {
        $spec = Get-PropertyValue $artifact "spec"
        Test-DependencyDag @(Get-PropertyValue $spec "workPackages") {
            param($node)
            @(Get-PropertyValue $node "dependsOn")
        } "$($artifactFile.FullName) fixture work packages"
    }
}

Write-Host " - Markdown links and anchors"
$markdownFiles = @(
    Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Filter "*.md"
    Get-Item -LiteralPath (Join-Path $repoRoot "README.md")
    Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter "*.md"
)
$anchorCache = @{}
foreach ($markdownFile in $markdownFiles) {
    $text = Get-Content -LiteralPath $markdownFile.FullName -Raw
    $linkPattern = '(?<!!)\[[^\]]+\]\((?<target><[^>]+>|[^)\s]+)(?:\s+["''][^)]*["''])?\)'
    foreach ($match in [regex]::Matches($text, $linkPattern)) {
        $target = $match.Groups["target"].Value.Trim("<", ">")
        if ($target -match "^(?:https?|mailto):" -or $target -match "\{\{") {
            continue
        }

        $hashIndex = $target.IndexOf("#")
        if ($hashIndex -ge 0) {
            $pathPart = $target.Substring(0, $hashIndex)
            $anchor = [System.Uri]::UnescapeDataString($target.Substring($hashIndex + 1))
        }
        else {
            $pathPart = $target
            $anchor = ""
        }

        if ([string]::IsNullOrEmpty($pathPart)) {
            $targetPath = $markdownFile.FullName
        }
        else {
            $decodedPath = [System.Uri]::UnescapeDataString($pathPart)
            $targetPath = Resolve-ComponentPath $markdownFile.Directory.FullName $decodedPath
        }

        Add-Check (Test-Path -LiteralPath $targetPath) "Broken local link '$target' in $($markdownFile.FullName)."
        if (-not (Test-Path -LiteralPath $targetPath)) {
            continue
        }

        if (Test-Path -LiteralPath $targetPath -PathType Container) {
            $readmePath = Join-Path $targetPath "README.md"
            if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
                $targetPath = $readmePath
            }
        }

        if (-not [string]::IsNullOrEmpty($anchor) -and
            [System.IO.Path]::GetExtension($targetPath) -eq ".md") {
            if (-not $anchorCache.ContainsKey($targetPath)) {
                $anchorCache[$targetPath] = Get-MarkdownAnchors $targetPath
            }
            Add-Check ($anchorCache[$targetPath].Contains($anchor)) "Broken Markdown anchor '#$anchor' in link '$target' from $($markdownFile.FullName)."
        }
    }
}

Write-Host " - fixture coverage"
$expectedFiles = @(Get-ChildItem -LiteralPath $fixtureRoot -Recurse -File -Filter "expected.json")
Add-Check ($expectedFiles.Count -ge 3) "At least three fixture expectation artifacts are required."
$allCoverage = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($expectedFile in $expectedFiles) {
    $expected = $jsonDocuments[$expectedFile.FullName]
    $fixtureDirectory = $expectedFile.Directory.FullName
    foreach ($tag in @(Get-PropertyValue $expected "coverage")) {
        $null = $allCoverage.Add($tag)
    }

    foreach ($sourceFile in @(Get-PropertyValue $expected "sourceFiles")) {
        $sourcePath = Resolve-ComponentPath $fixtureDirectory $sourceFile
        Add-Check (Test-Path -LiteralPath $sourcePath -PathType Leaf) "Fixture source '$sourceFile' is missing for $($expectedFile.FullName)."
    }

    $inventory = Get-PropertyValue $expected "inventory"
    foreach ($fact in @(Get-PropertyValue $inventory "facts")) {
        $factPath = Resolve-ComponentPath $fixtureDirectory (Get-PropertyValue $fact "path")
        Add-Check (Test-Path -LiteralPath $factPath -PathType Leaf) "Fixture evidence path '$((Get-PropertyValue $fact "path"))' is missing."
        if (Test-Path -LiteralPath $factPath -PathType Leaf) {
            $lineCount = @(Get-Content -LiteralPath $factPath).Count
            $line = [int](Get-PropertyValue $fact "line")
            Add-Check ($line -le $lineCount) "Fixture evidence line $line exceeds $lineCount lines in $factPath."
        }
    }

    $riskIds = @((Get-PropertyValue $expected "risks") | ForEach-Object { Get-PropertyValue $_ "id" })
    $mapping = Get-PropertyValue $expected "mapping"
    Add-Check ((Get-PropertyValue $mapping "target") -eq "grpc-dotnet") "Fixture $($expectedFile.FullName) does not require the gRPC target."
    Add-Check ((Get-PropertyValue $mapping "targetRuntime") -eq "gRPC for .NET") "Fixture $($expectedFile.FullName) does not require gRPC for .NET."
    foreach ($risk in @(Get-PropertyValue $expected "risks")) {
        Add-Check ((Get-PropertyValue $risk "redesignRequired") -eq $true) "Fixture risk '$((Get-PropertyValue $risk "id"))' is not an explicit redesign risk."
    }
    foreach ($riskId in @(Get-PropertyValue $mapping "redesignRiskIds")) {
        Add-Check ($riskId -in $riskIds) "Fixture mapping references unknown redesign risk '$riskId'."
    }
    foreach ($question in @(Get-PropertyValue $expected "questions")) {
        foreach ($riskId in @(Get-PropertyValue $question "riskIds")) {
            Add-Check ($riskId -in $riskIds) "Fixture question references unknown risk '$riskId'."
        }
    }

    foreach ($xmlFile in Get-ChildItem -LiteralPath $fixtureDirectory -File | Where-Object Extension -in @(".config", ".csproj")) {
        try {
            $null = [xml](Get-Content -LiteralPath $xmlFile.FullName -Raw)
            Add-Check $true "XML parsed."
        }
        catch {
            Add-Check $false "Invalid fixture XML: $($xmlFile.FullName) ($($_.Exception.Message))"
        }
    }
}

$requiredCoverage = @(
    "basic-http", "unary", "client", "data-contract",
    "typed-fault", "message-security", "nullable", "default-value",
    "decimal", "date-time", "enum", "known-type",
    "duplex-callback", "one-way", "session", "transaction",
    "reliable-session", "streaming"
)
foreach ($tag in $requiredCoverage) {
    Add-Check ($allCoverage.Contains($tag)) "Fixture coverage is missing '$tag'."
}

$basicSource = Get-Content -LiteralPath (Join-Path $fixtureRoot "basic-unary/Contracts.cs") -Raw
$basicClient = Get-Content -LiteralPath (Join-Path $fixtureRoot "basic-unary/Program.cs") -Raw
$basicConfig = Get-Content -LiteralPath (Join-Path $fixtureRoot "basic-unary/App.config") -Raw
Add-Check ($basicSource -match "\[ServiceContract" -and $basicSource -match "\[OperationContract" -and $basicSource -match "\[DataContract") "Basic fixture lacks WCF contract constructs."
Add-Check ($basicClient -match "ChannelFactory<") "Basic fixture lacks a typed WCF client."
Add-Check ($basicConfig -match "basicHttpBinding") "Basic fixture lacks basicHttpBinding configuration."

$faultSource = Get-Content -LiteralPath (Join-Path $fixtureRoot "faults-and-serialization/Contracts.cs") -Raw
$faultService = Get-Content -LiteralPath (Join-Path $fixtureRoot "faults-and-serialization/InvoiceService.cs") -Raw
$faultConfig = Get-Content -LiteralPath (Join-Path $fixtureRoot "faults-and-serialization/App.config") -Raw
foreach ($pattern in @("FaultContract", "EmitDefaultValue", "decimal\?", "DateTime\?", "enum InvoiceState", "KnownType")) {
    Add-Check ($faultSource -match $pattern) "Fault/serialization fixture lacks pattern '$pattern'."
}
Add-Check ($faultService -match "FaultException<ValidationFault>") "Fault fixture does not throw its typed fault."
Add-Check ($faultConfig -match 'security mode="Message"' -and $faultConfig -match 'clientCredentialType="Windows"') "Fault fixture lacks message security configuration."

$duplexSource = Get-Content -LiteralPath (Join-Path $fixtureRoot "duplex-high-risk/Contracts.cs") -Raw
$duplexService = Get-Content -LiteralPath (Join-Path $fixtureRoot "duplex-high-risk/DispatchService.cs") -Raw
$duplexConfig = Get-Content -LiteralPath (Join-Path $fixtureRoot "duplex-high-risk/App.config") -Raw
foreach ($pattern in @("CallbackContract", "IsOneWay\s*=\s*true", "SessionMode\.Required", "TransactionFlow", "Stream Download", "Upload\(Stream")) {
    Add-Check ($duplexSource -match $pattern) "Duplex fixture lacks pattern '$pattern'."
}
Add-Check ($duplexService -match "InstanceContextMode\.PerSession" -and $duplexService -match "TransactionScopeRequired\s*=\s*true") "Duplex fixture lacks per-session transactional implementation."
Add-Check ($duplexConfig -match "reliableSession" -and $duplexConfig -match 'transferMode="Streamed"') "Duplex fixture lacks reliable-session or streamed binding configuration."

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Validation failed with $($script:Failures.Count) error(s) after $($script:Checks) checks:" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Validation passed: $($script:Checks) checks; $($allJsonFiles.Count) JSON files; $($schemaFiles.Count) schemas; $($markdownFiles.Count) Markdown files; $($expectedFiles.Count) fixtures." -ForegroundColor Green
