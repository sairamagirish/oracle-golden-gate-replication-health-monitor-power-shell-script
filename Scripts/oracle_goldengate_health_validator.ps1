########################################################################
# Script Name : Oracle Goldengate Health Validator
# Author : Sai Rama Girish Kuppili
# Purpose : Validate Oracle GoldenGate replication health by analyzing process status, lag trends, RBA movement,
#           trail progression, and replication activity.

# Use Cases:
# - Post Restart Validation
# - Maintenance Verification
# - Outage Recovery Checks
# - Routine Health Monitoring

# CONFIGURATION

# Update the following values before execution:

# GgsciPath : Full path to ggsci.exe
# OggHome : Oracle GoldenGate Home Directory
# LogFile : Location for health-check logs
# RbaCheckInterval : Time between health snapshots (seconds)

########################################################################


param(
    [string]$GgsciPath   = "F:\OGG\gg_home\ggsci.exe",
    [string]$OggHome     = "F:\OGG",
    [string]$LogFile     = "G:\test\ogg_health_$(Get-Date -Format 'yyyyMMdd').log",
    [int]$RbaCheckInterval = 120
)

# ─────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

# ─────────────────────────────────────────────────────────────
function Invoke-Ggsci {
    param([string]$Command)

    try {
        $tempInput  = [System.IO.Path]::GetTempFileName()
        $tempOutput = [System.IO.Path]::GetTempFileName()

        Set-Content -Path $tempInput -Value "$Command`nexit"

        $process = Start-Process -FilePath $GgsciPath `
            -ArgumentList "< `"$tempInput`"" `
            -WorkingDirectory $OggHome `
            -RedirectStandardOutput $tempOutput `
            -PassThru -NoNewWindow

        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw "GGSCI timeout"
        }

        $result = Get-Content -Path $tempOutput -Raw
        Remove-Item $tempInput, $tempOutput -Force -ErrorAction SilentlyContinue
        return $result
    }
    catch {
        Write-Log "GGSCI execution failed: $_" "ERROR"
        return ""
    }
}

# ─────────────────────────────────────────────────────────────
function Get-ProcessStatus {
    $output = Invoke-Ggsci "INFO ALL"
    $processes = @{}

    foreach ($line in ($output -split "`n")) {
        if ($line -match '^\s*(EXTRACT|REPLICAT|PUMP)\s+(\S+)\s+(\S+)\s+([\d:]+)') {
            $processes[$Matches[2]] = @{
                Type   = $Matches[1]
                Name   = $Matches[2]
                Status = $Matches[3]
                Lag    = $Matches[4]
            }
        }
    }
    return $processes
}

# ─────────────────────────────────────────────────────────────
function Get-ProcessRBA {
    param([string]$ProcessType, [string]$ProcessName)

    $output = Invoke-Ggsci "INFO $ProcessType $ProcessName DETAIL"

    $rba = $null; $seqno = $null

    foreach ($line in ($output -split "`n")) {
        if ($line -match 'Log Read Checkpoint.*Seqno\s+(\d+).*RBA\s+(\d+)') {
            $seqno = [int]$Matches[1]
            $rba   = [long]$Matches[2]
        }
    }
    return @{ RBA = $rba; Seqno = $seqno }
}

# ─────────────────────────────────────────────────────────────
function Get-LagSeconds {
    param([string]$Lag)

    if ($Lag -match '(\d+):(\d+):(\d+)') {
        return ([int]$Matches[1]*3600 + [int]$Matches[2]*60 + [int]$Matches[3])
    }
    return -1
}

# ─────────────────────────────────────────────────────────────
function Check-Stats {
    param([string]$ProcessType, [string]$ProcessName)

    $output = Invoke-Ggsci "STATS $ProcessType $ProcessName TOTAL"

    if ($output -match 'No records') {
        return "IDLE"
    }
    elseif ($output -match '\d+') {
        return "ACTIVE"
    }
    return "UNKNOWN"
}

# ─────────────────────────────────────────────────────────────
Write-Log "===== OGG HEALTH CHECK STARTED ====="

# SNAPSHOT 1
Write-Log "Snapshot 1: Initial State"
$snap1 = Get-ProcessStatus
$rbaSnap1 = @{}
$lagSnap1 = @{}

foreach ($proc in $snap1.Values) {
    Write-Log "Process: $($proc.Name) | Type: $($proc.Type) | Status: $($proc.Status) | Lag: $($proc.Lag)"

    $rbaSnap1[$proc.Name] = Get-ProcessRBA $proc.Type $proc.Name
    $lagSnap1[$proc.Name] = Get-LagSeconds $proc.Lag

    Write-Log "  Seqno: $($rbaSnap1[$proc.Name].Seqno) | RBA: $($rbaSnap1[$proc.Name].RBA)"
}

# WAIT
Write-Log "Waiting $RbaCheckInterval seconds..."
Start-Sleep -Seconds $RbaCheckInterval

# SNAPSHOT 2
Write-Log "Snapshot 2: Movement Check"
$snap2 = Get-ProcessStatus
$allHealthy = $true

foreach ($proc in $snap2.Values) {

    $rba2 = Get-ProcessRBA $proc.Type $proc.Name
    $lag2 = Get-LagSeconds $proc.Lag

    $rbaMove = $rba2.RBA - $rbaSnap1[$proc.Name].RBA
    $seqMove = $rba2.Seqno - $rbaSnap1[$proc.Name].Seqno
    $lagDelta = $lagSnap1[$proc.Name] - $lag2

    $stats = Check-Stats $proc.Type $proc.Name

    Write-Log "Process: $($proc.Name)"
    Write-Log "  Status      : $($proc.Status)"
    Write-Log "  Lag         : $($proc.Lag)"
    Write-Log "  Lag Delta   : $lagDelta sec"
    Write-Log "  RBA Move    : $rbaMove"
    Write-Log "  SEQ Move    : $seqMove"
    Write-Log "  Activity    : $stats"

    # HEALTH LOGIC
    if ($proc.Status -ne "RUNNING") {
        Write-Log "  [FAIL] Not RUNNING" "ERROR"
        $allHealthy = $false
    }
    elseif ($lagDelta -lt 0) {
        Write-Log "  [WARN] Lag increasing" "WARN"
    }
    elseif ($rbaMove -eq 0 -and $seqMove -eq 0 -and $stats -eq "ACTIVE") {
        Write-Log "  [WARN] No movement but stats show activity — possible issue" "WARN"
    }
    elseif ($rbaMove -gt 0 -or $seqMove -gt 0) {
        Write-Log "  [OK] Processing normally"
    }
    elseif ($stats -eq "IDLE") {
        Write-Log "  [OK] Idle system (no data)" 
    }
    else {
        Write-Log "  [WARN] Uncertain state" "WARN"
    }
}

# FINAL RESULT
Write-Log "===== FINAL RESULT ====="

if ($allHealthy) {
    Write-Log "✅ OGG HEALTHY: Processes running and data flowing"
} else {
    Write-Log "❌ OGG ISSUES DETECTED — Check immediately" "ERROR"
} 
