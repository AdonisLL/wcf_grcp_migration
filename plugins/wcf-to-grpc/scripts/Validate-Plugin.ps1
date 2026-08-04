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
$stableIdPattern = "^(?:INV|DLOG|MSPEC|ISET|REPO|SOL|PRJ|HOST|SVC|OP|DC|FLD|END|CON|DEP|EVD|RSK|QST|DEC|OPT|APV|SPEC|RPC|MSG|PF|PHS|WP|AC|VAL|ISSUE|LBL|TRC|IMP|VRPT|VF|FIX)-[a-z0-9]+(?:-[a-z0-9]+)*$"

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
    for ($index = 1; $index -lt $end; $index++) {
        if ($lines[$index] -match "^([A-Za-z][A-Za-z0-9_-]*):(?:\s*(.*))?$") {
            $frontmatter[$Matches[1]] = $Matches[2]
        }
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
    "name", "description", "version", "keywords", "skills", "agents",
    "hooks", "mcpServers", "lspServers"
) "Plugin manifest"
Test-AllowedProperties $repositoryPlugin @(
    "name", "description", "version", "keywords", "skills", "agents",
    "hooks", "mcpServers", "lspServers"
) "Repository plugin manifest"
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

$skillNames = @()
foreach ($skillFile in $skillFiles) {
    $frontmatter = Read-Frontmatter $skillFile.FullName
    foreach ($key in $frontmatter.Keys) {
        Add-Check ($key -in @("name", "description")) "Skill $($skillFile.FullName) has unsupported frontmatter field '$key'."
    }
    Add-Check ($frontmatter.ContainsKey("name")) "Skill $($skillFile.FullName) is missing frontmatter name."
    Add-Check ($frontmatter.ContainsKey("description")) "Skill $($skillFile.FullName) is missing frontmatter description."
    if ($frontmatter.ContainsKey("name")) {
        $skillNames += $frontmatter["name"]
        Add-Check ($frontmatter["name"] -eq $skillFile.Directory.Name) "Skill name '$($frontmatter["name"])' does not match directory '$($skillFile.Directory.Name)'."
    }
}
foreach ($duplicate in $skillNames | Group-Object | Where-Object Count -gt 1) {
    Add-Check $false "Duplicate skill name '$($duplicate.Name)'."
}

$agentNames = @()
foreach ($agentFile in $agentFiles) {
    $frontmatter = Read-Frontmatter $agentFile.FullName
    foreach ($key in $frontmatter.Keys) {
        Add-Check ($key -in @("name", "description", "tools")) "Agent $($agentFile.FullName) has unsupported frontmatter field '$key'."
    }
    foreach ($required in @("name", "description", "tools")) {
        Add-Check ($frontmatter.ContainsKey($required)) "Agent $($agentFile.FullName) is missing frontmatter $required."
    }
    if ($frontmatter.ContainsKey("name")) {
        $agentNames += $frontmatter["name"]
    }
    if ($frontmatter.ContainsKey("tools")) {
        $tools = $frontmatter["tools"].Trim().TrimStart("[").TrimEnd("]").Split(",") |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
        foreach ($tool in $tools) {
            Add-Check ($tool -in @("read", "search", "edit", "execute")) "Agent $($agentFile.FullName) declares unsupported tool '$tool'."
        }
    }
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
        Json = Join-Path $pluginRoot "skills/publish-migration-issues/examples/issue-set.example.json"
        Schema = Join-Path $pluginRoot "schemas/issue-set.schema.json"
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
