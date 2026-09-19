<#
.SYNOPSIS
  Read-only OpenCode resource discovery audit for Windows.

.DESCRIPTION
  Audits OpenCode commands, agents, and skills across all common global and
  project-local discovery roots. Explicitly follows one-level skill junctions/
  symlinks so toolkit-managed junctions are not skipped.

  Reports:
    - exact duplicate names
    - same-name/different-content conflicts
    - cross-type semantic collisions (github vs github-ops)
    - old singular discovery roots
    - remote skill-cache collisions
    - toolkit manifest drift/stale copies
    - toolkit resources outside the canonical deployment
    - active-project visibility

  Makes no changes.

  Windows PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    [string]$ToolkitRoot = 'F:\_ai-toolkit',
    [string]$ScanRoot = 'F:\',
    [string]$ActiveDirectory = '',
    [switch]$Deep,
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
if (-not $ActiveDirectory) { $ActiveDirectory = (Get-Location).Path }

if (-not $ToolkitRoot) {
    $locator = Join-Path $HomeDir '.config\opencode\ai-toolkit-root.txt'
    if (Test-Path -LiteralPath $locator) {
        try { $ToolkitRoot = (Get-Content -LiteralPath $locator -Raw).Trim() } catch {}
    }
}
if (-not $OutDir) {
    $OutDir = if (Test-Path -LiteralPath $ToolkitRoot) {
        Join-Path $ToolkitRoot '.state\discovery-audit'
    } else {
        Join-Path $env:TEMP 'opencode-discovery-audit'
    }
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$txtPath = Join-Path $OutDir "opencode-discovery-v2-$stamp.txt"
$jsonPath = Join-Path $OutDir "opencode-discovery-v2-$stamp.json"
$report = New-Object System.Collections.ArrayList

function O([string]$s='') { Write-Host $s; [void]$script:report.Add($s) }
function S([string]$s) { O ''; O ('='*78); O $s; O ('='*78) }
function Full([string]$p) { if(-not $p){return $null}; try{[IO.Path]::GetFullPath($p)}catch{return $p} }
function FileHash([string]$p) {
    if($p -and (Test-Path -LiteralPath $p -PathType Leaf)){
        try{return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}catch{}
    }
    return $null
}
function LinkInfo([string]$p) {
    try {
        $i=Get-Item -LiteralPath $p -Force
        $rp=(($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
        $lt=$null;$tg=$null
        if($rp){
            if($i.PSObject.Properties.Name -contains 'LinkType'){$lt=[string]$i.LinkType}
            if($i.PSObject.Properties.Name -contains 'Target'){$tg=[string]($i.Target -join '; ')}
        }
        return [pscustomobject]@{Reparse=$rp;LinkType=$lt;Target=$tg}
    } catch { return [pscustomobject]@{Reparse=$false;LinkType=$null;Target=$null} }
}
function SkillMeta([string]$p) {
    $name=$null;$desc=$null
    try {
        $ls=Get-Content -LiteralPath $p -Encoding UTF8
        $n=[Math]::Min($ls.Count,80)
        for($i=0;$i -lt $n;$i++){
            if(-not $name -and $ls[$i] -match '^\s*name\s*:\s*["'']?([^"'']+)["'']?\s*$'){$name=$Matches[1].Trim()}
            if(-not $desc -and $ls[$i] -match '^\s*description\s*:\s*(.+?)\s*$'){$desc=$Matches[1].Trim()}
        }
    } catch {}
    [pscustomobject]@{Name=$name;Description=$desc}
}
function AddRec($list,[string]$type,[string]$name,[string]$path,[string]$content,[string]$scope,[string]$origin){
    if(-not $name){return}
    $li=LinkInfo $path
    [void]$list.Add([pscustomobject]@{
        Type=$type
        Name=$name
        Path=(Full $path)
        ContentPath=(Full $content)
        Scope=$scope
        Origin=$origin
        Hash=(FileHash $content)
        IsReparse=$li.Reparse
        LinkType=$li.LinkType
        LinkTarget=$li.Target
    })
}

function ScanSkillRoot($list,[string]$root,[string]$scope,[string]$origin) {
    if(-not (Test-Path -LiteralPath $root -PathType Container)){return}

    # Root-level .md skills, if present.
    foreach($md in @(Get-ChildItem -LiteralPath $root -File -Filter '*.md' -ErrorAction SilentlyContinue)){
        if($md.Name -ieq 'SKILL.md'){continue}
        $m=SkillMeta $md.FullName
        $nm=if($m.Name){$m.Name}else{[IO.Path]::GetFileNameWithoutExtension($md.Name)}
        AddRec $list 'skill' $nm $md.FullName $md.FullName $scope $origin
    }

    # IMPORTANT: enumerate immediate children, then directly address SKILL.md.
    # This works even when each skill directory itself is a junction/symlink.
    foreach($d in @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue)){
        $skill=Join-Path $d.FullName 'SKILL.md'
        if(Test-Path -LiteralPath $skill -PathType Leaf){
            $m=SkillMeta $skill
            $nm=if($m.Name){$m.Name}else{$d.Name}
            AddRec $list 'skill' $nm $d.FullName $skill $scope $origin
        }

        # Also catch nested skills inside ordinary (non-reparse) grouping directories.
        $li=LinkInfo $d.FullName
        if(-not $li.Reparse){
            foreach($nested in @(Get-ChildItem -LiteralPath $d.FullName -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue)){
                if($nested.FullName -eq $skill){continue}
                $m=SkillMeta $nested.FullName
                $nm=if($m.Name){$m.Name}else{Split-Path -Leaf (Split-Path -Parent $nested.FullName)}
                AddRec $list 'skill' $nm (Split-Path -Parent $nested.FullName) $nested.FullName $scope $origin
            }
        }
    }
}
function ScanMdRoot($list,[string]$root,[string]$type,[string]$scope,[string]$origin){
    if(-not (Test-Path -LiteralPath $root -PathType Container)){return}
    foreach($md in @(Get-ChildItem -LiteralPath $root -File -Filter '*.md' -ErrorAction SilentlyContinue)){
        $nm=[IO.Path]::GetFileNameWithoutExtension($md.Name)
        AddRec $list $type $nm $md.FullName $md.FullName $scope $origin
    }
}
function ScanProject($list,[string]$pr,[string]$scope){
    foreach($r in @('.opencode\skills','.opencode\skill','.agents\skills','.claude\skills')){
        ScanSkillRoot $list (Join-Path $pr $r) $scope $r
    }
    foreach($r in @('.opencode\agents','.opencode\agent')){
        ScanMdRoot $list (Join-Path $pr $r) 'agent' $scope $r
    }
    foreach($r in @('.opencode\commands','.opencode\command')){
        ScanMdRoot $list (Join-Path $pr $r) 'command' $scope $r
    }
}
function Norm([string]$s){ if(-not $s){return ''}; (($s.ToLowerInvariant()) -replace '[^a-z0-9]','') }
function SemanticBase([string]$s){
    $n=Norm $s
    foreach($suffix in @('operations','operator','ops','githubops','tools','tool','skill','agent','command')){
        if($n.EndsWith($suffix) -and $n.Length -gt $suffix.Length+2){
            return $n.Substring(0,$n.Length-$suffix.Length)
        }
    }
    return $n
}
function IsSemanticallySimilar([string]$a,[string]$b){
    $na=Norm $a;$nb=Norm $b
    if(-not $na -or -not $nb){return $false}
    if($na -eq $nb){return $true}
    if(($na.StartsWith($nb) -or $nb.StartsWith($na)) -and [Math]::Abs($na.Length-$nb.Length) -le 10){return $true}
    $ba=SemanticBase $a;$bb=SemanticBase $b
    if($ba -and $ba -eq $bb -and $ba.Length -ge 3){return $true}

    # Explicit common wrapper pattern: github <-> github-ops.
    if(($na -eq 'github' -and $nb -eq 'githubops') -or ($nb -eq 'github' -and $na -eq 'githubops')){return $true}
    return $false
}

$rec=New-Object System.Collections.ArrayList
$canon=New-Object System.Collections.ArrayList

S 'OpenCode discovery audit v2'
O "Time:            $(Get-Date -Format o)"
O "Home:            $HomeDir"
O "ToolkitRoot:     $ToolkitRoot"
O "ScanRoot:        $ScanRoot"
O "ActiveDirectory: $ActiveDirectory"

$global=@(
 @{T='skill';P=(Join-Path $HomeDir '.config\opencode\skills');O='native-global-plural'},
 @{T='skill';P=(Join-Path $HomeDir '.config\opencode\skill');O='native-global-singular'},
 @{T='skill';P=(Join-Path $HomeDir '.agents\skills');O='agents-compat-global'},
 @{T='skill';P=(Join-Path $HomeDir '.claude\skills');O='claude-compat-global'},
 @{T='agent';P=(Join-Path $HomeDir '.config\opencode\agents');O='native-global-plural'},
 @{T='agent';P=(Join-Path $HomeDir '.config\opencode\agent');O='native-global-singular'},
 @{T='command';P=(Join-Path $HomeDir '.config\opencode\commands');O='native-global-plural'},
 @{T='command';P=(Join-Path $HomeDir '.config\opencode\command');O='native-global-singular'}
)
S 'Global discovery roots'
foreach($r in $global){
    $exists=Test-Path -LiteralPath $r.P
    O ("{0,-8} {1,-7} {2}" -f $r.T,$(if($exists){'EXISTS'}else{'-'}),$r.P)
    if($exists){
        if($r.T -eq 'skill'){ScanSkillRoot $rec $r.P 'global' $r.O}
        else{ScanMdRoot $rec $r.P $r.T 'global' $r.O}
    }
}

$cache=if($env:XDG_CACHE_HOME){Join-Path $env:XDG_CACHE_HOME 'opencode\skills'}else{Join-Path $HomeDir '.cache\opencode\skills'}
O ''
O "Remote skill cache: $(if(Test-Path -LiteralPath $cache){'EXISTS'}else{'-'}) $cache"
if(Test-Path -LiteralPath $cache){ScanSkillRoot $rec $cache 'cache' 'remote-cache'}

$projects=@()
if(Test-Path -LiteralPath $ScanRoot){
    foreach($d in @(Get-ChildItem -LiteralPath $ScanRoot -Directory -Force -ErrorAction SilentlyContinue)){
        if((Test-Path (Join-Path $d.FullName '.git')) -or
           (Test-Path (Join-Path $d.FullName '.opencode')) -or
           (Test-Path (Join-Path $d.FullName '.agents')) -or
           (Test-Path (Join-Path $d.FullName '.claude'))){
            $projects += $d.FullName
            ScanProject $rec $d.FullName "project:$($d.FullName)"
        }
    }
}

# Active project chain to git root.
$activeAnc=@()
if(Test-Path -LiteralPath $ActiveDirectory -PathType Container){
    $gitRoot=$null
    try{
        $gr=& git -C $ActiveDirectory rev-parse --show-toplevel 2>$null
        if($LASTEXITCODE -eq 0 -and $gr){$gitRoot=Full ($gr|Select-Object -First 1)}
    }catch{}
    $cur=Full $ActiveDirectory
    while($cur){
        $activeAnc += $cur
        if($gitRoot -and $cur.TrimEnd('\') -ieq $gitRoot.TrimEnd('\')){break}
        $parent=Split-Path -Parent $cur
        if(-not $parent -or $parent -eq $cur){break}
        $cur=$parent
    }
}
$active=New-Object System.Collections.ArrayList
foreach($x in @($rec|Where-Object{$_.Scope -eq 'global' -or $_.Scope -eq 'cache'})){[void]$active.Add($x)}
foreach($a in $activeAnc){
    $tmp=New-Object System.Collections.ArrayList
    ScanProject $tmp $a "active-project:$a"
    foreach($x in $tmp){[void]$active.Add($x)}
}

# Canonical source path changed across toolkit editions. Scan either/both.
$canonicalSkillRoots=@(
    (Join-Path $ToolkitRoot 'skills'),
    (Join-Path $ToolkitRoot '.agents\skills')
)|Where-Object{Test-Path -LiteralPath $_}|Select-Object -Unique
foreach($sr in $canonicalSkillRoots){ScanSkillRoot $canon $sr 'toolkit-source' 'canonical'}
ScanMdRoot $canon (Join-Path $ToolkitRoot 'opencode\agents') 'agent' 'toolkit-source' 'canonical'
ScanMdRoot $canon (Join-Path $ToolkitRoot 'opencode\commands') 'command' 'toolkit-source' 'canonical'

$manifest=@()
$mp=Join-Path $ToolkitRoot '.state\install-manifest.json'
if(Test-Path -LiteralPath $mp){
    try{$manifest=@((Get-Content -LiteralPath $mp -Raw|ConvertFrom-Json))}catch{O "WARN manifest parse: $($_.Exception.Message)"}
}
$managedTargets=@($manifest|ForEach-Object{if($_.target){Full ([string]$_.target)}})

S 'Exact duplicate names'
$dups=@($rec|Group-Object Type,Name|Where-Object{$_.Count -gt 1}|Sort-Object Name)
if(-not $dups.Count){O 'No exact duplicate names found.'}
foreach($g in $dups){
    $hs=@($g.Group|Where-Object{$_.Hash}|Select-Object -ExpandProperty Hash -Unique)
    $kind=if($hs.Count -le 1){'SAME-CONTENT'}else{'DIFFERENT-CONTENT'}
    O ''
    O "$kind :: $($g.Group[0].Type) '$($g.Group[0].Name)' ($($g.Count))"
    foreach($x in $g.Group){
        O "  [$($x.Scope)] $($x.Path) managed=$($managedTargets -contains $x.Path)"
        if($x.IsReparse){O "     link=$($x.LinkType) -> $($x.LinkTarget)"}
    }
}

S 'Cross-type semantic collisions'
$uniq=@($rec|Select-Object Type,Name,Path,Scope -Unique)
$collisions=New-Object System.Collections.ArrayList
for($i=0;$i -lt $uniq.Count;$i++){
    for($j=$i+1;$j -lt $uniq.Count;$j++){
        if($uniq[$i].Name -eq $uniq[$j].Name -and $uniq[$i].Type -eq $uniq[$j].Type){continue}
        if(IsSemanticallySimilar $uniq[$i].Name $uniq[$j].Name){
            [void]$collisions.Add([pscustomobject]@{
                AType=$uniq[$i].Type;AName=$uniq[$i].Name;APath=$uniq[$i].Path
                BType=$uniq[$j].Type;BName=$uniq[$j].Name;BPath=$uniq[$j].Path
            })
        }
    }
}
if(-not $collisions.Count){O 'No cross-type/similar-name collisions found.'}
foreach($c in @($collisions|Sort-Object AName,BName,APath,BPath -Unique)){
    O "$($c.AType):$($c.AName) <-> $($c.BType):$($c.BName)"
    O "  $($c.APath)"
    O "  $($c.BPath)"
}

S 'Active project resources'
O "Active chain: $($activeAnc -join ' -> ')"
$activeDups=@($active|Group-Object Type,Name|Where-Object{$_.Count -gt 1}|Sort-Object Name)
if(-not $activeDups.Count){O 'No same-type exact duplicates simultaneously active.'}
foreach($g in $activeDups){
    O "ACTIVE DUPLICATE $($g.Group[0].Type):$($g.Group[0].Name)"
    foreach($x in $g.Group){O "  $($x.Path)"}
}
$activeUniq=@($active|Select-Object Type,Name,Path -Unique)
for($i=0;$i -lt $activeUniq.Count;$i++){
    for($j=$i+1;$j -lt $activeUniq.Count;$j++){
        if($activeUniq[$i].Type -eq $activeUniq[$j].Type -and $activeUniq[$i].Name -eq $activeUniq[$j].Name){continue}
        if(IsSemanticallySimilar $activeUniq[$i].Name $activeUniq[$j].Name){
            O "ACTIVE COLLISION: $($activeUniq[$i].Type):$($activeUniq[$i].Name) <-> $($activeUniq[$j].Type):$($activeUniq[$j].Name)"
        }
    }
}

S 'Manifest drift'
$drift=0
foreach($m in $manifest){
    $tp=Full ([string]$m.target);$sp=Full ([string]$m.source)
    if(-not (Test-Path -LiteralPath $tp)){O "MISSING TARGET: $tp";$drift++;continue}
    if($sp -and -not (Test-Path -LiteralPath $sp)){O "MISSING SOURCE: $sp";$drift++;continue}
    if($m.method -eq 'copy' -and $m.kind -eq 'file' -and (Test-Path -LiteralPath $sp -PathType Leaf)){
        $sh=FileHash $sp;$th=FileHash $tp
        if($sh -and $th -and $sh -ne $th){O "STALE COPY: $tp <- $sp";$drift++}
    }
}
if(-not $drift){O 'No manifest drift detected.'}

S 'Unmanaged toolkit-name discoveries'
foreach($c in $canon){
    foreach($h in @($rec|Where-Object{$_.Type -eq $c.Type -and $_.Name -eq $c.Name})){
        if($managedTargets -notcontains $h.Path -and $h.Scope -ne 'toolkit-source'){
            O "UNMANAGED $($h.Type):$($h.Name) -> $($h.Path)"
        }
    }
}

S 'Remote cache'
$cached=@($rec|Where-Object{$_.Scope -eq 'cache'})
if(-not $cached.Count){O 'No cached remote skills found.'}
foreach($x in $cached){O "$($x.Type):$($x.Name) -> $($x.Path)"}

$data=if($env:XDG_DATA_HOME){Join-Path $env:XDG_DATA_HOME 'opencode'}else{Join-Path $HomeDir '.local\share\opencode'}
S 'OpenCode storage'
foreach($q in @($data,(Join-Path $data 'log'),(Join-Path $data 'opencode.db'),$cache)){if(Test-Path -LiteralPath $q){O "EXISTS $q"}}

if($Deep){
    S 'Recent log correlation'
    $ld=Join-Path $data 'log'
    if(Test-Path -LiteralPath $ld){
        $logs=@(Get-ChildItem -LiteralPath $ld -File|Sort-Object LastWriteTime -Descending|Select-Object -First 10)
        $need=@($rec|ForEach-Object{$_.Path}|Where-Object{$_}|Select-Object -Unique)
        foreach($log in $logs){
            try{
                $t=Get-Content -LiteralPath $log.FullName -Raw
                $hits=@($need|Where-Object{$t.IndexOf($_,[StringComparison]::OrdinalIgnoreCase) -ge 0})
                if($hits.Count){O "LOG $($log.Name)";foreach($h in $hits){O "  $h"}}
            }catch{}
        }
    }
}

S 'Clean-install implications'
O 'A clean install should:'
O '  1. Stop OpenCode completely.'
O '  2. Remove manifest-owned toolkit resources.'
O '  3. Remove recognized retired toolkit names from every GLOBAL discovery root.'
O '  4. Never delete project-local resources automatically; report them.'
O '  5. Install one canonical copy/link per resource.'
O '  6. Verify deployed file hashes and junction targets.'
O '  7. Re-run this audit and require zero stale managed copies.'
O '  8. Restart OpenCode into a new session.'

$result=[pscustomobject]@{
    generated_at=(Get-Date).ToString('o')
    toolkit_root=$ToolkitRoot
    scan_root=$ScanRoot
    active_directory=$ActiveDirectory
    active_ancestors=@($activeAnc)
    records=@($rec)
    active_records=@($active)
    canonical=@($canon)
    manifest=@($manifest)
    exact_duplicates=@($dups|ForEach-Object{[pscustomobject]@{type=$_.Group[0].Type;name=$_.Group[0].Name;entries=@($_.Group)}})
    semantic_collisions=@($collisions)
}
$result|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $jsonPath -Encoding UTF8
$report|Set-Content -LiteralPath $txtPath -Encoding UTF8

S 'Finished'
O "Text report: $txtPath"
O "JSON report: $jsonPath"
O 'No files were changed.'
