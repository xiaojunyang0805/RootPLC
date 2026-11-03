# Install rootplc on Windows (PowerShell):
#   irm https://raw.githubusercontent.com/xiaojunyang0805/RootPLC/main/scripts/install.ps1 | iex
# Options (environment): ROOTPLC_VERSION=v0.1.0 (default: latest release),
#                        ROOTPLC_INSTALL_DIR (default: %LOCALAPPDATA%\rootplc\bin)
# Without a release it falls back to building with cargo.
$ErrorActionPreference = 'Stop'
$repo = 'xiaojunyang0805/RootPLC'
$dir = if ($env:ROOTPLC_INSTALL_DIR) { $env:ROOTPLC_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'rootplc\bin' }
$version = if ($env:ROOTPLC_VERSION) { $env:ROOTPLC_VERSION } else { 'latest' }
$base = if ($version -eq 'latest') { "https://github.com/$repo/releases/latest/download" } else { "https://github.com/$repo/releases/download/$version" }
$asset = 'rootplc-x86_64-pc-windows-msvc.zip'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("rootplc-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    try {
        Invoke-WebRequest "$base/$asset" -OutFile (Join-Path $tmp $asset) -UseBasicParsing
        Invoke-WebRequest "$base/$asset.sha256" -OutFile (Join-Path $tmp "$asset.sha256") -UseBasicParsing
    } catch {
        Write-Host 'rootplc: no release binary found; building from source with cargo.'
        if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { throw 'install Rust first: https://rustup.rs' }
        cargo install --locked --git "https://github.com/$repo" rootplc-cli
        return
    }
    $expected = ((Get-Content (Join-Path $tmp "$asset.sha256")) -split '\s+')[0].ToLower()
    $actual = (Get-FileHash (Join-Path $tmp $asset) -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) { throw 'rootplc: checksum mismatch' }
    Expand-Archive (Join-Path $tmp $asset) -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item (Join-Path $tmp 'rootplc.exe') (Join-Path $dir 'rootplc.exe') -Force
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$dir", 'User')
        Write-Host "added $dir to your user PATH (open a new terminal)"
    }
    Write-Host "rootplc installed to $dir\rootplc.exe"
    & (Join-Path $dir 'rootplc.exe') --version
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
