# =============================================================================
# 🔑 GENERATE APP CONTENT KEY
# =============================================================================
# Génère une clé AES-256 sécurisée pour le chiffrement des assets CDN
#
# ⚠️  ATTENTION: Cette clé doit être:
#     1. Générée UNE SEULE FOIS
#     2. Stockée de manière sécurisée (.secrets/ est dans .gitignore)
#     3. Encodée dans le code natif (secure_key.cpp) pour l'app
#     4. JAMAIS partagée publiquement
#
# USAGE:
#   .\generate_content_key.ps1
#
# @author EduCam Security Team
# @version 1.0
# =============================================================================

param(
    [string]$OutputPath = ".\.secrets\app_content_key.bin",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔑 EDUCAM CONTENT KEY GENERATOR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Créer le répertoire si nécessaire
$secretsDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
    Write-Host "✓ Created directory: $secretsDir" -ForegroundColor Green
}

# Vérifier si la clé existe déjà
if ((Test-Path $OutputPath) -and -not $Force) {
    Write-Host "⚠️  Key already exists: $OutputPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To regenerate, run with -Force flag:" -ForegroundColor Gray
    Write-Host "  .\generate_content_key.ps1 -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⚠️  WARNING: Regenerating the key will make ALL existing encrypted" -ForegroundColor Red
    Write-Host "   assets unreadable. Only do this for a fresh installation." -ForegroundColor Red
    Write-Host ""
    exit 0
}

# Générer 32 bytes (256 bits) de données aléatoires cryptographiquement sécurisées
$key = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($key)

# Sauvegarder la clé
[System.IO.File]::WriteAllBytes($OutputPath, $key)

Write-Host "✓ Generated 256-bit AES key" -ForegroundColor Green
Write-Host "✓ Saved to: $OutputPath" -ForegroundColor Green
Write-Host ""

# Afficher la clé en format C++ pour l'intégration native
Write-Host "══════════════════════════════════════════════════════════════════=" -ForegroundColor Yellow
Write-Host "  📋 C++ ARRAY FOR NATIVE INTEGRATION (secure_key.cpp)" -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════════════=" -ForegroundColor Yellow
Write-Host ""
Write-Host "// Clé AES-256 pour déchiffrement des assets CDN" -ForegroundColor Gray
Write-Host "static const unsigned char CONTENT_KEY[] = {" -ForegroundColor White

$lines = @()
for ($i = 0; $i -lt $key.Length; $i += 8) {
    $bytes = @()
    for ($j = $i; $j -lt [Math]::Min($i + 8, $key.Length); $j++) {
        $bytes += "0x{0:X2}" -f $key[$j]
    }
    $line = "    " + ($bytes -join ", ")
    if ($i + 8 -lt $key.Length) {
        $line += ","
    }
    $lines += $line
}

foreach ($line in $lines) {
    Write-Host $line -ForegroundColor Cyan
}

Write-Host "};" -ForegroundColor White
Write-Host ""

# Générer aussi le XOR mask pour l'obfuscation
Write-Host "══════════════════════════════════════════════════════════════════=" -ForegroundColor Yellow
Write-Host "  🔒 XOR ENCODED VERSION (pour stockage obfusqué)" -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════════════=" -ForegroundColor Yellow
Write-Host ""

# Utiliser le même XOR_MASK que dans secure_key.cpp
$xorMask = @(
    0x7A, 0x3F, 0x91, 0xC2, 0x5E, 0x8D, 0xB4, 0x17,
    0x6C, 0xA9, 0x23, 0xF0, 0x4B, 0xD6, 0x82, 0xE5,
    0x1F, 0x68, 0xAC, 0x39, 0x75, 0xCE, 0x04, 0x9B,
    0x52, 0xE7, 0x2D, 0x88, 0xF3, 0x41, 0xBF, 0x66
)

$encodedKey = New-Object byte[] 32
for ($i = 0; $i -lt 32; $i++) {
    $encodedKey[$i] = $key[$i] -bxor $xorMask[$i]
}

Write-Host "static const unsigned char ENCODED_CONTENT_KEY[] = {" -ForegroundColor White

$lines = @()
for ($i = 0; $i -lt $encodedKey.Length; $i += 8) {
    $bytes = @()
    for ($j = $i; $j -lt [Math]::Min($i + 8, $encodedKey.Length); $j++) {
        $bytes += "0x{0:X2}" -f $encodedKey[$j]
    }
    $line = "    " + ($bytes -join ", ")
    if ($i + 8 -lt $encodedKey.Length) {
        $line += ","
    }
    $lines += $line
}

foreach ($line in $lines) {
    Write-Host $line -ForegroundColor Cyan
}

Write-Host "};" -ForegroundColor White
Write-Host ""

# Nettoyer les clés de la mémoire
[Array]::Clear($key, 0, $key.Length)
[Array]::Clear($encodedKey, 0, $encodedKey.Length)

Write-Host "══════════════════════════════════════════════════════════════════=" -ForegroundColor Green
Write-Host "  ✅ KEY GENERATION COMPLETE" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════════=" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Copy the ENCODED_CONTENT_KEY to secure_key.cpp" -ForegroundColor Gray
Write-Host "  2. Add a JNI function to retrieve the content key" -ForegroundColor Gray
Write-Host "  3. Test encryption: .\encrypt_assets.ps1 -InputPath test.pdf -OutputDir out" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  SECURITY REMINDER:" -ForegroundColor Red
Write-Host "  - .secrets/ folder is in .gitignore (verify!)" -ForegroundColor Gray
Write-Host "  - Never commit app_content_key.bin to Git" -ForegroundColor Gray
Write-Host "  - Backup the key securely (password manager, etc.)" -ForegroundColor Gray
Write-Host ""
