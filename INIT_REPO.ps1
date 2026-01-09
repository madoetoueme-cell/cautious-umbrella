# =============================================================================
# ☂️ CAUTIOUS UMBRELLA - INIT SCRIPT
# =============================================================================
# Ce script initialise ce dossier comme un dépôt Git indépendant
# connecté à votre repo de stockage d'assets.
#
# USAGE:
#   .\INIT_REPO.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'

Write-Host '☂️  Initialisation du QG Cautious Umbrella...' -ForegroundColor Cyan

# 1. Initialiser Git
if (-not (Test-Path '.git')) {
    git init
    Write-Host '✓ Git repository initialized.' -ForegroundColor Green
} else {
    Write-Host 'ℹ️  Git already initialized.' -ForegroundColor Yellow
}

# 2. Configurer le remote (VOTRE REPO SECRET)
$remoteUrl = 'https://github.com/madoetoueme-cell/cautious-umbrella.git'
$currentRemote = git remote get-url origin 2>$null

if (-not $currentRemote) {
    git remote add origin $remoteUrl
    Write-Host '✓ Remote origin added: $remoteUrl' -ForegroundColor Green
} elseif ($currentRemote -ne $remoteUrl) {
    git remote set-url origin $remoteUrl
    Write-Host '✓ Remote origin updated to: $remoteUrl' -ForegroundColor Green
} else {
    Write-Host 'ℹ️  Remote already configured.' -ForegroundColor Yellow
}

# 3. Premier Pull (pour récupérer le README s'il existe déjà)
Write-Host '⬇️  Pulling from main...' -ForegroundColor Cyan
git pull origin main 2>$null

# 4. Instructions
Write-Host ''
Write-Host '✅ PRET À L EMPLOI !' -ForegroundColor Green
Write-Host ''
Write-Host 'WORKFLOW :' -ForegroundColor Yellow
Write-Host '1. Mettez vos PDFs dans le dossier raw_pdfs' -ForegroundColor Gray
Write-Host '2. Lancez l encryption :' -ForegroundColor Gray
Write-Host '   .\encrypt_assets.ps1 -InputDir .\raw_pdfs -OutputDir .\assets' -ForegroundColor Gray
Write-Host '3. Envoyez sur GitHub :' -ForegroundColor Gray
Write-Host '   git add .' -ForegroundColor Gray
Write-Host '   git commit -m Ajout nouveaux sujets' -ForegroundColor Gray
Write-Host '   git push -u origin main' -ForegroundColor Gray
Write-Host ''
