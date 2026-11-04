# PixNab — script de création des DMG

## Installation

Copie `release-dmg.sh` **à la racine de ton dépôt PixNab**, à côté de `run.sh` et `AppInfo.plist` :

```bash
cd /chemin/vers/PixNab-v0.22.0
cp ~/Downloads/release-dmg.sh ./release-dmg.sh
chmod +x ./release-dmg.sh
```

> Tu peux également extraire le ZIP téléchargé, puis copier `PixNab-release-dmg/release-dmg.sh` vers la racine de ton projet.

## Utilisation

```bash
./release-dmg.sh --show-version      # Version actuelle depuis AppInfo.plist
./release-dmg.sh                     # DMG de la version actuelle, sans changer le numéro
./release-dmg.sh --bump patch        # 0.22.2 -> 0.22.3
./release-dmg.sh --bump minor        # 0.22.2 -> 0.23.0
./release-dmg.sh --bump major        # 0.22.2 -> 1.0.0
./release-dmg.sh --version 0.22.2    # Fixer explicitement une version plus récente
./release-dmg.sh --bump patch --test # Tests Swift avant la compilation
```

**Important :** la version actuelle peut encore être `0.22.0` dans `AppInfo.plist`, même si les correctifs v0.22.1 et v0.22.2 ont été appliqués. Vérifie ce numéro avec `--show-version` avant de publier. N'emploie la version `0.22.2` que si tu as effectivement intégré et testé les correctifs correspondants.

### Fonctionnement

1. Lit la version `CFBundleShortVersionString` et le numéro de build `CFBundleVersion` dans `AppInfo.plist`.
2. Si demandé, met la version à jour et incrémente le numéro de build de 1.
3. Lance `./run.sh --build` (et optionnellement `./run.sh --test`).
4. Vérifie la signature de l'application et le numéro de version du `.app` produit.
5. Crée un dossier **temporaire** `dmg-stage` avec `PixNab.app` et le lien `Applications`.
6. Crée un DMG compressé `dist/PixNab-vX.Y.Z.dmg`, puis vérifie son intégrité.
7. **Supprime automatiquement le dossier `dmg-stage`**, même en cas d'échec. En cas d'échec, restaure aussi le `AppInfo.plist` original après un changement de version.

Le script **ne remplace jamais un DMG existant**. Si `dist/PixNab-vX.Y.Z.dmg` existe déjà, il s'arrête. Corrige le problème et supprime ou renomme l'ancien DMG avant de relancer. Les autres versions restent intactes.

### Limites importantes

- Conçu pour **macOS**, avec Xcode/Swift CLI, Python 3, `codesign`, `ditto` et `hdiutil`.
- Le script existant `run.sh` effectue une signature **ad hoc**, sans certificat Developer ID. Le DMG ne sera **pas notarisé**. Les utilisateurs pourront rencontrer une alerte Gatekeeper.
- Pas d'envoi automatique à GitHub : inspecte et teste le DMG avant de publier la release.
- N'assure pas la construction d'un binaire universel Intel + Apple Silicon. Vérifie l'architecture et la compatibilité avant publication.
- Après un changement de version, **commit `AppInfo.plist` et `release-dmg.sh`**, puis crée le tag Git correspondant au commit publié.

## Publication GitHub (après validation de l'installation)

```bash
git add AppInfo.plist release-dmg.sh
git commit -m "Prepare PixNab v0.22.2"
git push origin main

git tag -a v0.22.2 -m "PixNab v0.22.2"
git push origin v0.22.2

# Optionnel : GitHub CLI, après connexion avec gh auth login
gh release create v0.22.2 dist/PixNab-v0.22.2.dmg \
  --title "PixNab v0.22.2" --prerelease --verify-tag --generate-notes
```

Adapte `0.22.2` à la version que tu as vraiment compilée. Ne crée pas un tag existant une seconde fois.
