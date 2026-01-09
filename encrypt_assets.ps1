# =============================================================================
# 🔐 ENCRYPT ASSETS - EduCam Stealth Courier
# =============================================================================
# Script PowerShell pour préparer les PDFs avant upload sur le CDN GitHub
#
# WORKFLOW:
# 1. PDF original → GZIP compression → AES-256-GCM encryption → .bin output
# 2. Génère un manifeste JSON pour Firestore
#
# USAGE:
#   .\encrypt_assets.ps1 -InputPath ".\pdfs\maths_bac_2024.pdf" -OutputDir ".\encrypted"
#   .\encrypt_assets.ps1 -InputDir ".\pdfs\" -OutputDir ".\encrypted" -Recursive
#
# PRÉREQUIS:
#   - PowerShell 7+ (pour les cmdlets crypto modernes)
#   - Le fichier de clé: .secrets/app_content_key.bin (32 bytes)
#
# @author EduCam Security Team
# @version 1.0
# @date 2026-01-09
# =============================================================================

param(
    [Parameter(ParameterSetName = "SingleFile")]
    [string]$InputPath,
    
    [Parameter(ParameterSetName = "Directory")]
    [string]$InputDir,
    
    [Parameter(Mandatory = $true)]
    [string]$OutputDir,
    
    [Parameter(ParameterSetName = "Directory")]
    [switch]$Recursive,
    
    [string]$KeyFile = ".\.secrets\app_content_key.bin",
    
    [string]$ManifestOutput = ".\manifest.json",
    
    [switch]$Verbose
)

# =============================================================================
# CONFIGURATION
# =============================================================================

$ErrorActionPreference = "Stop"
$ALGORITHM = "AES"
$KEY_SIZE = 256
$IV_SIZE = 12      # GCM standard
$TAG_SIZE = 16     # GCM auth tag

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $emoji = switch ($Level) {
        "INFO" { "ℹ️" }
        "SUCCESS" { "✅" }
        "WARNING" { "⚠️" }
        "ERROR" { "❌" }
        "DEBUG" { "🔍" }
        default { "📝" }
    }
    Write-Host "[$timestamp] $emoji $Message"
}

function Get-SHA256Hash {
    param([string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Compress-ToGzip {
    param(
        [string]$InputPath,
        [string]$OutputPath
    )
    
    $inputStream = [System.IO.File]::OpenRead($InputPath)
    $outputStream = [System.IO.File]::Create($OutputPath)
    $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionLevel]::Optimal)
    
    try {
        $inputStream.CopyTo($gzipStream)
    }
    finally {
        $gzipStream.Close()
        $outputStream.Close()
        $inputStream.Close()
    }
    
    return (Get-Item $OutputPath).Length
}

function Encrypt-FileAesGcm {
    <#
    .SYNOPSIS
    Chiffre un fichier avec AES-256-GCM
    
    .DESCRIPTION
    Format de sortie:
    - 12 bytes: IV (Initialization Vector)
    - N bytes: Données chiffrées
    - 16 bytes: Authentication Tag (GCM)
    
    Ce format est compatible avec CryptoManager.decryptFileToStream() d'Android
    #>
    param(
        [byte[]]$Key,
        [string]$InputPath,
        [string]$OutputPath
    )
    
    # Générer un IV aléatoire
    $iv = New-Object byte[] $IV_SIZE
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($iv)
    
    # Lire le fichier source
    $plainData = [System.IO.File]::ReadAllBytes($InputPath)
    
    # Créer l'objet AES-GCM (.NET 5+)
    $aesGcm = [System.Security.Cryptography.AesGcm]::new($Key)
    
    # Préparer les buffers
    $cipherData = New-Object byte[] $plainData.Length
    $tag = New-Object byte[] $TAG_SIZE
    
    # Chiffrer
    $aesGcm.Encrypt($iv, $plainData, $cipherData, $tag)
    
    # Écrire le fichier de sortie: IV + CipherText + Tag
    $outputStream = [System.IO.File]::Create($OutputPath)
    try {
        $outputStream.Write($iv, 0, $iv.Length)
        $outputStream.Write($cipherData, 0, $cipherData.Length)
        $outputStream.Write($tag, 0, $tag.Length)
    }
    finally {
        $outputStream.Close()
        $aesGcm.Dispose()
    }
    
    # Nettoyer la mémoire sensible
    [Array]::Clear($plainData, 0, $plainData.Length)
    [Array]::Clear($cipherData, 0, $cipherData.Length)
    
    return (Get-Item $OutputPath).Length
}

function Generate-ObfuscatedName {
    <#
    .SYNOPSIS
    Génère un nom de fichier obfusqué basé sur le hash SHA-256
    #>
    param([string]$OriginalPath)
    
    $hash = Get-SHA256Hash -FilePath $OriginalPath
    # Prendre les 16 premiers caractères du hash pour le nom
    return $hash.Substring(0, 16) + ".bin"
}

function Process-SingleFile {
    param(
        [string]$InputPath,
        [string]$OutputDir,
        [byte[]]$Key
    )
    
    $fileName = [System.IO.Path]::GetFileName($InputPath)
    Write-Log "Processing: $fileName" "INFO"
    
    # 1. Créer un fichier temporaire compressé
    $tempGzip = [System.IO.Path]::GetTempFileName()
    
    try {
        # 2. Compression GZIP
        $originalSize = (Get-Item $InputPath).Length
        $compressedSize = Compress-ToGzip -InputPath $InputPath -OutputPath $tempGzip
        $compressionRatio = [math]::Round(($compressedSize / $originalSize) * 100, 1)
        Write-Log "  Compressed: $originalSize → $compressedSize bytes ($compressionRatio%)" "DEBUG"
        
        # 3. Générer le nom obfusqué
        $obfuscatedName = Generate-ObfuscatedName -OriginalPath $InputPath
        $outputPath = Join-Path $OutputDir $obfuscatedName
        
        # 4. Chiffrement AES-GCM
        $encryptedSize = Encrypt-FileAesGcm -Key $Key -InputPath $tempGzip -OutputPath $outputPath
        Write-Log "  Encrypted: $outputPath ($encryptedSize bytes)" "DEBUG"
        
        # 5. Calculer le checksum du fichier chiffré
        $checksum = Get-SHA256Hash -FilePath $outputPath
        
        # 6. Retourner les métadonnées pour le manifeste
        return @{
            original_name       = $fileName
            cdn_path            = "assets/$obfuscatedName"
            checksum            = $checksum
            size_bytes          = $encryptedSize
            original_size_bytes = $originalSize
            compression_ratio   = $compressionRatio
            version             = 1
            encrypted_at        = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'")
        }
    }
    finally {
        # Nettoyer le fichier temporaire
        if (Test-Path $tempGzip) {
            Remove-Item $tempGzip -Force
        }
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔐 EDUCAM ASSET ENCRYPTION TOOL - Stealth Courier Pipeline" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Vérifier que le fichier de clé existe
if (-not (Test-Path $KeyFile)) {
    Write-Log "Key file not found: $KeyFile" "ERROR"
    Write-Host ""
    Write-Host "To generate a key, run:" -ForegroundColor Yellow
    Write-Host "  `$key = New-Object byte[] 32" -ForegroundColor Gray
    Write-Host "  [System.Security.Cryptography.RandomNumberGenerator]::Fill(`$key)" -ForegroundColor Gray
    Write-Host "  [System.IO.File]::WriteAllBytes('.\.secrets\app_content_key.bin', `$key)" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Charger la clé
$key = [System.IO.File]::ReadAllBytes($KeyFile)
if ($key.Length -ne 32) {
    Write-Log "Invalid key size: expected 32 bytes, got $($key.Length)" "ERROR"
    exit 1
}
Write-Log "Key loaded successfully (256-bit AES)" "SUCCESS"

# Créer le répertoire de sortie si nécessaire
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Log "Created output directory: $OutputDir" "INFO"
}

# Collecter les fichiers à traiter
$filesToProcess = @()

if ($PSCmdlet.ParameterSetName -eq "SingleFile") {
    if (-not (Test-Path $InputPath)) {
        Write-Log "Input file not found: $InputPath" "ERROR"
        exit 1
    }
    $filesToProcess += Get-Item $InputPath
}
else {
    if (-not (Test-Path $InputDir)) {
        Write-Log "Input directory not found: $InputDir" "ERROR"
        exit 1
    }
    
    $searchOption = if ($Recursive) { "AllDirectories" } else { "TopDirectoryOnly" }
    $filesToProcess = Get-ChildItem -Path $InputDir -Filter "*.pdf" -File -Recurse:$Recursive
    
    if ($filesToProcess.Count -eq 0) {
        Write-Log "No PDF files found in: $InputDir" "WARNING"
        exit 0
    }
}

Write-Log "Files to process: $($filesToProcess.Count)" "INFO"
Write-Host ""

# Traiter chaque fichier et collecter les manifestes
$manifests = @()
$successCount = 0
$errorCount = 0

foreach ($file in $filesToProcess) {
    try {
        $manifest = Process-SingleFile -InputPath $file.FullName -OutputDir $OutputDir -Key $key
        $manifests += $manifest
        $successCount++
        Write-Log "  ✓ $($file.Name) → $($manifest.cdn_path)" "SUCCESS"
    }
    catch {
        $errorCount++
        Write-Log "  ✗ $($file.Name): $_" "ERROR"
    }
}

# Générer le manifeste global
$globalManifest = @{
    version      = "1.0"
    generated_at = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'")
    files_count  = $manifests.Count
    files        = $manifests
}

$manifestJson = $globalManifest | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ManifestOutput, $manifestJson, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  📊 RÉSUMÉ" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Log "Processed: $successCount files" "SUCCESS"
if ($errorCount -gt 0) {
    Write-Log "Errors: $errorCount files" "ERROR"
}
Write-Log "Manifest: $ManifestOutput" "INFO"
Write-Log "Output: $OutputDir" "INFO"
Write-Host ""

# Afficher les instructions pour l'upload
Write-Host "📤 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Copy files from '$OutputDir' to GitHub repo 'educam-assets/assets/'" -ForegroundColor Gray
Write-Host "  2. Copy manifest entries to Firestore collection 'subjects'" -ForegroundColor Gray
Write-Host "  3. Files will be available at: cdn.jsdelivr.net/gh/OWNER/educam-assets@main/assets/HASH.bin" -ForegroundColor Gray
Write-Host ""

# Nettoyer la clé de la mémoire
[Array]::Clear($key, 0, $key.Length)
