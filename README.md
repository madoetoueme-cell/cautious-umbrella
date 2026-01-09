# 📦 EduCam Assets CDN

> **Repository de stockage des assets chiffrés pour l'application EduCam**

Ce repo héberge les fichiers PDF chiffrés (sujets d'examen, cours, etc.) accessibles via le CDN jsDelivr.

## 🌐 Accès CDN

Les fichiers sont accessibles via :
```
https://cdn.jsdelivr.net/gh/madoetoueme-cell/cautious-umbrella@main/assets/HASH.bin
```

## 📁 Structure

```
cautious-umbrella/
├── README.md           # Ce fichier
├── assets/             # Fichiers chiffrés (.bin)
│   ├── a1b2c3d4e5f6.bin
│   ├── b2c3d4e5f6g7.bin
│   └── ...
└── manifests/          # Manifestes JSON (optionnel, backup)
    └── 2026-01-09.json
```

## 🔐 Format des fichiers

Chaque fichier `.bin` contient un PDF chiffré avec :
- **Compression** : GZIP
- **Chiffrement** : AES-256-GCM
- **Structure** : `[IV 12 bytes][Data][Tag 16 bytes]`

Seule l'application EduCam possède la clé de déchiffrement.

## 📋 Ajouter de nouveaux fichiers

### 1. Préparer les PDFs
```powershell
cd EduCam/tools
.\encrypt_assets.ps1 -InputDir ".\mes_pdfs\" -OutputDir ".\encrypted"
```

### 2. Copier les fichiers
```powershell
Copy-Item .\encrypted\*.bin ..\educam-assets\assets\
```

### 3. Commit & Push
```bash
cd ../educam-assets
git add .
git commit -m "Add: Nouveaux sujets BAC 2025"
git push
```

### 4. Mettre à jour Firestore
Copier les entrées du `manifest.json` généré vers la collection `subjects` de Firestore.

## ⚡ Cache jsDelivr

Le CDN met en cache les fichiers pendant **7 jours**. Pour forcer un rafraîchissement :
```
https://purge.jsdelivr.net/gh/OWNER/educam-assets@main/assets/HASH.bin
```

## ⚠️ Important

- **Ne jamais** commit de fichiers non chiffrés
- **Ne jamais** partager la clé de chiffrement
- Les fichiers chiffrés sont **inutilisables** sans l'app EduCam

## 📊 Statistiques

| Métrique | Valeur |
|----------|--------|
| Fichiers | _à compléter_ |
| Taille totale | _à compléter_ |
| Dernière MàJ | _à compléter_ |

---

**© 2024-2026 EduCam / VŒRTEX_E.A**
