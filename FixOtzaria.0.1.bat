<# :
@echo off
:: --- התחלת חלק אצווה (Batch) ---
:: בדיקה אם יש הרשאות מנהל, אם לא - מבקש ומפעיל מחדש
fltmc >nul 2>&1 || (
  echo Requesting Administrator privileges...
  PowerShell Start-Process -FilePath '%0' -Verb RunAs
  exit /b
)

:: הרצת קוד ה-PowerShell המוטמע למטה
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {[ScriptBlock]::Create((Get-Content '%~f0' -Raw -Encoding UTF8)).Invoke()}"
goto :eof
#>

# --- מכאן מתחיל קוד ה-PowerShell ---

# הגדרות ברירת מחדל
$DefaultPath = "C:\אוצריא"
$ManifestFileName = "files_manifest.json"
$RemovedLog = ".\removed_manifest_entries.txt"
$ErrorActionPreference = 'Stop'

Write-Host "--- אוטומציה לתיקון מניפסט אוצריא ---" -ForegroundColor Cyan
Write-Host ""

# שלב 1: זיהוי הנתיב
if (Test-Path $DefaultPath) {
    $RootPath = $DefaultPath
    Write-Host "נמצאה תיקיית אוצריא במיקום ברירת המחדל: $RootPath" -ForegroundColor Green
} else {
    Write-Host "לא נמצאה תיקייה במיקום C:\אוצריא" -ForegroundColor Yellow
    $RootPath = Read-Host "אנא הדבק כאן את הנתיב המלא לתיקיית אוצריא ולחץ Enter"
    
    # הסרת מרכאות אם המשתמש העתיק אותן בטעות
    $RootPath = $RootPath -replace '"', ''
    
    if (-not (Test-Path $RootPath)) {
        Write-Host "שגיאה: הנתיב שהוזן לא קיים. יציאה." -ForegroundColor Red
        Read-Host "לחץ Enter לסגירה"
        exit
    }
}

$ManifestPath = Join-Path -Path $RootPath -ChildPath $ManifestFileName

Write-Host ""
Write-Host "קובץ מניפסט: $ManifestPath"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Host "שגיאה: קובץ המניפסט לא נמצא בנתיב זה!" -ForegroundColor Red
    Read-Host "לחץ Enter לסגירה"
    exit
}

# יצירת גיבוי
$backupPath = "$ManifestPath.bak"
Copy-Item -LiteralPath $ManifestPath -Destination $backupPath -Force
Write-Host "גיבוי נוצר בהצלחה: $backupPath" -ForegroundColor Gray

Write-Host "סורק את כל הקבצים בתיקייה (זה עשוי לקחת רגע)..." -ForegroundColor Yellow

# איסוף שמות קבצים
$allFiles = Get-ChildItem -Path $RootPath -Recurse -File
$existingNames = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($file in $allFiles) {
    [void]$existingNames.Add($file.Name)
}

Write-Host "נמצאו $($existingNames.Count) קבצים פיזיים."
Write-Host "טוען את המניפסט..."

# טעינת ה-JSON
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

Write-Host "סך הכל רשומות במניפסט: $totalEntries"
Write-Host "רשומות להסרה: $($keysToRemove.Count)"

# שמירת לוג של מה שהוסר
if ($keysToRemove.Count -gt 0) {
    $keysToRemove | Set-Content -LiteralPath $RemovedLog -Encoding UTF8
    Write-Host "רשימת המפתחות שהוסרו נשמרה בקובץ: $RemovedLog"

    # הסרה מהאובייקט
    foreach ($k in $keysToRemove) {
        [void]$data.PSObject.Properties.Remove($k)
    }

    # שמירה מחדש
    $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

    Write-Host "-------------------------------------------"
    Write-Host "התהליך הושלם בהצלחה!" -ForegroundColor Green
    Write-Host "הוסרו $($keysToRemove.Count) רשומות."
    Write-Host "המניפסט המעודכן נשמר."
    Write-Host "-------------------------------------------"
} else {
    Write-Host "-------------------------------------------"
    Write-Host "הכל תקין, לא נדרשו שינויים." -ForegroundColor Green
    Write-Host "-------------------------------------------"
}

Read-Host "לחץ Enter לסיום וסגירת החלון"