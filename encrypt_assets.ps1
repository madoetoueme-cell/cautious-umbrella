# ENCRYPT ASSETS - EduCam Stealth Courier (ASCII Version)
param(
    [Parameter(ParameterSetName="SingleFile")]
    [string]$InputPath,
    [Parameter(ParameterSetName="Directory")]
    [string]$InputDir,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    [Parameter(ParameterSetName="Directory")]
    [switch]$Recursive,
    [string]$KeyFile = ".\.secrets\app_content_key.bin",
    [string]$ManifestOutput = ".\manifest.json"
)

$ErrorActionPreference = "Stop"
$IV_SIZE = 12
$TAG_SIZE = 16

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch($Level) {
        "INFO"    { "[i]" }
        "SUCCESS" { "[+]" }
        "WARNING" { "[!]" }
        "ERROR"   { "[X]" }
        default   { "[*]" }
    }
    Write-Host "[$timestamp] $prefix $Message"
}

function Get-SHA256Hash {
    param([string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Compress-ToGzip {
    param([string]$InputPath, [string]$OutputPath)
    $inputStream = [System.IO.File]::OpenRead($InputPath)
    $outputStream = [System.IO.File]::Create($OutputPath)
    $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionLevel]::Optimal)
    try { $inputStream.CopyTo($gzipStream) }
    finally { $gzipStream.Close(); $outputStream.Close(); $inputStream.Close() }
    return (Get-Item $OutputPath).Length
}

function Encrypt-FileAesGcm {
    param([byte[]]$Key, [string]$InputPath, [string]$OutputPath)
    $iv = New-Object byte[] $IV_SIZE
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($iv)
    $plainData = [System.IO.File]::ReadAllBytes($InputPath)
    $aesGcm = [System.Security.Cryptography.AesGcm]::new($Key)
    $cipherData = New-Object byte[] $plainData.Length
    $tag = New-Object byte[] $TAG_SIZE
    $aesGcm.Encrypt($iv, $plainData, $cipherData, $tag)
    $outputStream = [System.IO.File]::Create($OutputPath)
    try {
        $outputStream.Write($iv, 0, $iv.Length)
        $outputStream.Write($cipherData, 0, $cipherData.Length)
        $outputStream.Write($tag, 0, $tag.Length)
    } finally { $outputStream.Close(); $aesGcm.Dispose() }
    [Array]::Clear($plainData, 0, $plainData.Length)
    return (Get-Item $OutputPath).Length
}

function Generate-ObfuscatedName {
    param([string]$OriginalPath)
    $hash = Get-SHA256Hash -FilePath $OriginalPath
    return $hash.Substring(0, 16) + ".bin"
}

function Process-SingleFile {
    param([string]$InputPath, [string]$OutputDir, [byte[]]$Key)
    $fileName = [System.IO.Path]::GetFileName($InputPath)
    Write-Log "Processing: $fileName" "INFO"
    $tempGzip = [System.IO.Path]::GetTempFileName()
    try {
        $originalSize = (Get-Item $InputPath).Length
        $compressedSize = Compress-ToGzip -InputPath $InputPath -OutputPath $tempGzip
        $obfuscatedName = Generate-ObfuscatedName -OriginalPath $InputPath
        $outputPath = Join-Path $OutputDir $obfuscatedName
        $encryptedSize = Encrypt-FileAesGcm -Key $Key -InputPath $tempGzip -OutputPath $outputPath
        $checksum = Get-SHA256Hash -FilePath $outputPath
        Write-Log "  -> $obfuscatedName ($encryptedSize bytes)" "SUCCESS"
        return @{
            original_name = $fileName
            cdn_path = "assets/$obfuscatedName"
            checksum = $checksum
            size_bytes = $encryptedSize
            original_size_bytes = $originalSize
            version = 1
            encrypted_at = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'")
        }
    } finally { if (Test-Path $tempGzip) { Remove-Item $tempGzip -Force } }
}

Write-Host "====== EDUCAM ASSET ENCRYPTION ======" -ForegroundColor Cyan
if (-not (Test-Path $KeyFile)) {
    Write-Log "Key file not found: $KeyFile" "ERROR"
    exit 1
}
$key = [System.IO.File]::ReadAllBytes((Resolve-Path $KeyFile).Path)
if ($key.Length -ne 32) { Write-Log "Invalid key size" "ERROR"; exit 1 }
Write-Log "Key loaded (256-bit AES)" "SUCCESS"
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$filesToProcess = @()
if ($InputPath) { $filesToProcess += Get-Item $InputPath }
else { $filesToProcess = Get-ChildItem -Path $InputDir -Filter "*.pdf" -File -Recurse:$Recursive }
Write-Log "Files to process: $($filesToProcess.Count)" "INFO"
$manifests = @()
foreach ($file in $filesToProcess) {
    try {
        $manifest = Process-SingleFile -InputPath $file.FullName -OutputDir $OutputDir -Key $key
        $manifests += $manifest
    } catch { Write-Log "Failed: $($file.Name) - $_" "ERROR" }
}
$globalManifest = @{ version = "1.0"; generated_at = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"); files_count = $manifests.Count; files = $manifests }
$manifestJson = $globalManifest | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ManifestOutput, $manifestJson, [System.Text.Encoding]::UTF8)
Write-Host "====== DONE ======" -ForegroundColor Green
Write-Log "Manifest: $ManifestOutput" "SUCCESS"
[Array]::Clear($key, 0, $key.Length)
