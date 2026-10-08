function Find-NapCatWorkspaceRoot {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    if ($env:MON_WORKSPACE_ROOT -and (Test-Path -LiteralPath $env:MON_WORKSPACE_ROOT -PathType Container)) {
        return (Get-Item -LiteralPath $env:MON_WORKSPACE_ROOT).FullName
    }
    $Project = Get-Item -LiteralPath $ProjectRoot
    $Current = $Project
    while ($Current) {
        if (Test-Path -LiteralPath (Join-Path $Current.FullName '.monworkspace') -PathType Leaf) {
            return $Current.FullName
        }
        $Current = $Current.Parent
    }
    # Preserve standalone/legacy layouts without a workspace marker.
    return $Project.Parent.FullName
}

function Find-NapCatMonPmContext {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $Current = Get-Item -LiteralPath $ProjectRoot
    # Source workspace, nested DLC and sibling portable layouts.
    for ($Level = 0; $Current -and $Level -lt 4; $Level++) {
        $Candidates = @($Current.FullName, (Join-Path $Current.FullName 'EDEN_win'))
        if ($env:MON_WORKSPACE_ROOT) { $Candidates = @($env:MON_WORKSPACE_ROOT) + $Candidates }
        foreach ($Candidate in $Candidates) {
            $Exe = Join-Path $Candidate 'bin\monpm.exe'
            $Base = Join-Path $Candidate 'monpm.json'
            $Merged = Join-Path $Candidate '.run\monpm\monpm.dlc.json'
            if ((Test-Path -LiteralPath $Exe -PathType Leaf) -and
                (Test-Path -LiteralPath (Join-Path $Candidate '.monworkspace') -PathType Leaf) -and
                (Test-Path -LiteralPath $Base -PathType Leaf)) {
                $Config = if (Test-Path -LiteralPath $Merged -PathType Leaf) { $Merged } else { $Base }
                return @{ Root = $Candidate; Executable = $Exe; Config = $Config }
            }
        }
        $Current = $Current.Parent
    }
    return $null
}
