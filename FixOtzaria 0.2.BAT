<# :
@echo off
:: --- Batch Section ---
:: Request Admin privileges
fltmc >nul 2>&1 || (
  echo Requesting Administrator privileges...
  PowerShell Start-Process -FilePath '%0' -Verb RunAs
  exit /b
)

:: Run PowerShell Logic
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {[ScriptBlock]::Create((Get-Content '%~f0' -Raw -Encoding UTF8)).Invoke()}"
goto :eof
#>

# --- PowerShell Section ---

$DefaultPath = "C:\אוצריא"
$ManifestFileName = "files_manifest.json"
$RemovedLog = ".\removed_manifest_entries.txt"
$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "--- Otzaria Manifest Fix / תיקון מניפסט אוצריא ---" -ForegroundColor Cyan
Write-Host ""

# Step 1: Detect Path
if (Test-Path $DefaultPath) {
    $RootPath = $DefaultPath
    Write-Host "Found Otzaria folder at default location: $RootPath" -ForegroundColor Green
    Write-Host "נמצאה תיקיית אוצריא במיקום ברירת המחדל" -ForegroundColor Green
} else {
    Write-Host "Folder not found at C:\Otzaria / לא נמצאה תיקייה במיקום ברירת המחדל" -ForegroundColor Yellow
    $RootPath = Read-Host "Please paste full path here and press Enter / אנא הדבק את הנתיב המלא ולחץ אנטר"
    
    # Remove quotes
    $RootPath = $RootPath -replace '"', ''
    
    if (-not (Test-Path $RootPath)) {
        Write-Host "Error: Path not found. Exiting. / שגיאה: הנתיב לא נמצא. יציאה." -ForegroundColor Red
        Read-Host "Press Enter to close / לחץ אנטר לסגירה"
        exit
    }
}

$ManifestPath = Join-Path -Path $RootPath -ChildPath $ManifestFileName

Write-Host ""
Write-Host "Manifest file: $ManifestPath"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Host "Error: Manifest file missing! / שגיאה: קובץ המניפסט חסר!" -ForegroundColor Red
    Read-Host "Press Enter to close / לחץ אנטר לסגירה"
    exit
}

# Create Backup
$backupPath = "$ManifestPath.bak"
Copy-Item -LiteralPath $ManifestPath -Destination $backupPath -Force
Write-Host "Backup created: $backupPath / נוצר גיבוי לקובץ" -ForegroundColor Gray

Write-Host "Scanning files (please wait)... / סורק קבצים (נא להמתין)..." -ForegroundColor Yellow

# Collect files
$allFiles = Get-ChildItem -Path $RootPath -Recurse -File
$existingNames = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($file in $allFiles) {
    [void]$existingNames.Add($file.Name)
}

Write-Host "Found $($existingNames.Count) physical files. / נמצאו קבצים פיזיים."
Write-Host "Loading manifest... / טוען את המניפסט..."

# Load JSON
$jsonText = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
$data     = $jsonText | ConvertFrom-Json

$keysToRemove = New-Object System.Collections.Generic.List[string]
$totalEntries = 0

foreach ($prop in $data.PSObject.Properties) {
    $key = $prop.Name
    $totalEntries++

    if ($key -eq "metadata.json") {
        continue
    }

    $relPath = $key -replace '/', '\'
    $fileName = [System.IO.Path]::GetFileName($relPath)

    if (-not $existingNames.Contains($fileName)) {
        $keysToRemove.Add($key)
    }
}

Write-Host "Total manifest entries: $totalEntries / סה'כ רשומות"
Write-Host "Entries to remove: $($keysToRemove.Count) / רשומות להסרה"

if ($keysToRemove.Count -gt 0) {
    # Save Log
    $keysToRemove | Set-Content -LiteralPath $RemovedLog -Encoding UTF8
    Write-Host "Removed keys saved to log file / רשימת הקבצים שהוסרו נשמרה בקובץ לוג"

    # Remove from object
    foreach ($k in $keysToRemove) {
        [void]$data.PSObject.Properties.Remove($k)
    }

    # Save Manifest
    $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

    Write-Host "-------------------------------------------"
    Write-Host "Success! / הצליח!" -ForegroundColor Green
    Write-Host "Removed $($keysToRemove.Count) entries. / הוסרו רשומות."
    Write-Host "Manifest updated. / המניפסט עודכן."
    Write-Host "-------------------------------------------"
} else {
    Write-Host "-------------------------------------------"
    Write-Host "All good, no changes needed. / הכל תקין, לא נדרשו שינויים." -ForegroundColor Green
    Write-Host "-------------------------------------------"
}

Read-Host "Press Enter to exit / לחץ אנטר ליציאה"