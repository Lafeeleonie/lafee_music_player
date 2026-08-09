$addonName = "Lafee_music_player"
$playlistDir = Join-Path $PSScriptRoot "playlist"
$blDir = Join-Path $PSScriptRoot "bl"
$playlistLua = Join-Path $PSScriptRoot "playlist.lua"

$extensions = @(".mp3", ".ogg", ".wav")

function Convert-ToWowPath {
    param([string] $Path)

    $relativePath = $Path.Substring($PSScriptRoot.Length).TrimStart("\", "/")
    return "Interface\\AddOns\\$addonName\\" + ($relativePath -replace "[\\/]", "\\")
}

if (-not (Test-Path -LiteralPath $playlistDir)) {
    New-Item -ItemType Directory -Path $playlistDir | Out-Null
}

if (-not (Test-Path -LiteralPath $blDir)) {
    New-Item -ItemType Directory -Path $blDir | Out-Null
}

$tracks = Get-ChildItem -LiteralPath $playlistDir -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object Name |
    ForEach-Object { Convert-ToWowPath $_.FullName }

$blTrack = Get-ChildItem -LiteralPath $blDir -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object Name |
    Select-Object -First 1 |
    ForEach-Object { Convert-ToWowPath $_.FullName }

if (-not $blTrack) {
    $blTrack = "Interface\\AddOns\\$addonName\\bl\\bloodlust.mp3"
}

$lines = @()
$lines += "LafeeMusicPlayerTracks = {"
foreach ($track in $tracks) {
    $lines += "    `"$track`","
}
$lines += "}"
$lines += ""
$lines += "LafeeMusicPlayerBLTrack = `"$blTrack`""

Set-Content -LiteralPath $playlistLua -Value $lines -Encoding ASCII
Write-Host "playlist.lua mis a jour avec $($tracks.Count) musique(s)."
Write-Host "Musique BL: $blTrack"
