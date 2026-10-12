<#
.SYNOPSIS
    Adds the Android photo-read permissions to an AndroidManifest.xml file.

.DESCRIPTION
    Injects the two permission lines the app needs in order to list and read
    photos from the system gallery on Android:

      1. android.permission.READ_MEDIA_IMAGES        (Android 13 / API 33+)
      2. android.permission.READ_EXTERNAL_STORAGE    (Android 12 and below)
         with android:maxSdkVersion="32"

    The two lines are inserted directly before the closing </manifest> tag,
    which places them AFTER </application> - that is where <uses-permission>
    elements belong. Placing them inside <application> would break the build.

    The script is IDEMPOTENT: it checks whether a permission name is already
    present and only inserts what is missing, so running it many times never
    duplicates a line. A one-time backup AndroidManifest.xml.bak is created
    before the first change.

.PARAMETER ManifestPath
    Absolute or relative path to the AndroidManifest.xml to modify.

.OUTPUTS
    Exit code 0 - manifest is correct (nothing to do, or permissions added).
    Exit code 2 - the manifest file does not exist.
    Exit code 3 - the manifest has no closing </manifest> tag.
    Exit code 1 - any other unexpected error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

# --- The permissions we need, as [name, extra attributes] pairs -------------
$requiredPermissions = @(
    @{ Name = 'android.permission.READ_MEDIA_IMAGES';     Extra = '' },
    @{ Name = 'android.permission.READ_EXTERNAL_STORAGE'; Extra = ' android:maxSdkVersion="32"' }
)

# --- 1. the manifest has to exist -------------------------------------------
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Host "  ERROR: manifest not found: $ManifestPath"
    Write-Host "  HINT : run 'flutter create --platforms android .' first (build_and_run.bat does this for you)."
    exit 2
}

# --- 2. read the file, remembering the original encoding --------------------
$raw = [System.IO.File]::ReadAllText($ManifestPath)

# Keep the line ending style of the original file.
$newline = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }

# --- 3. work out which permissions are still missing ------------------------
$missingLines = New-Object System.Collections.Generic.List[string]

foreach ($permission in $requiredPermissions) {
    # Match on the permission NAME only, and tolerate any legal XML quoting
    # and spacing style, so a hand-written line such as
    #   android:name='android.permission.READ_MEDIA_IMAGES'/>
    # is still recognised as "already present" and never duplicated.
    $pattern = 'android:name\s*=\s*[''"]' + [regex]::Escape($permission.Name) + '[''"]'
    if ($raw -match $pattern) {
        Write-Host ("  [skip] already present : " + $permission.Name)
    } else {
        Write-Host ("  [add ] inserting        : " + $permission.Name)
        $missingLines.Add('    <uses-permission android:name="' + $permission.Name + '"' + $permission.Extra + ' />')
    }
}

if ($missingLines.Count -eq 0) {
    Write-Host '  All required permissions are already present. Nothing to do.'
    exit 0
}

# --- 4. find the closing </manifest> tag ------------------------------------
# LastIndexOf is used on purpose: a manifest has exactly one </manifest>, but
# using the last one is the safest choice if the file was hand-edited.
$closingTag = '</manifest>'
$insertAt = $raw.LastIndexOf($closingTag, [System.StringComparison]::Ordinal)

if ($insertAt -lt 0) {
    Write-Host "  ERROR: no closing </manifest> tag found in $ManifestPath"
    Write-Host '  HINT : the file looks corrupted. Delete the android\ folder and run this script again.'
    exit 3
}

# --- 5. build the new file content ------------------------------------------
$block = ($missingLines -join $newline) + $newline
$updated = $raw.Substring(0, $insertAt) + $block + $raw.Substring($insertAt)

# --- 6. back up once, then write UTF-8 WITHOUT BOM --------------------------
# A BOM in AndroidManifest.xml confuses the Android manifest merger, so the
# file is always written as plain UTF-8 without BOM.
$backupPath = $ManifestPath + '.bak'
if (-not (Test-Path -LiteralPath $backupPath)) {
    [System.IO.File]::Copy($ManifestPath, $backupPath)
    Write-Host "  [note] backup created     : $backupPath"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ManifestPath, $updated, $utf8NoBom)

Write-Host ("  [ok  ] permissions written : " + $missingLines.Count + " line(s) added before </manifest>")
Write-Host '  AndroidManifest.xml is ready.'
exit 0
