# TestFlight privé

- App Store Connect : **MangaFlow reader**, ID `6824043882`, SKU `mangaflow` (fiche créée par l'utilisateur).
- Bundle ID : `fr.yannick.mangaflow`.
- Équipe Apple : `KY6RHJR4LZ`.
- Groupe interne : **Yannick — Personnel**, limité à `yannick.herrero@proton.me`, lien public désactivé.
- Profil App Store : **MangaFlow Internal App Store 20261017**, associé au certificat de distribution déjà présent dans le trousseau du Mac.

Aucun mot de passe, JWT, fichier `.p8` ou certificat privé n'est versionné. Le client reçoit le chemin d'une configuration externe contenant `issuer_id`, `key_id`, `key_path` (et éventuellement `team_id`). Le certificat et sa clé privée restent dans le trousseau macOS. Ne pas accepter une nouvelle convention Apple automatiquement : elle doit être acceptée par le titulaire du compte.

## Préparer une version

Incrémenter `CURRENT_PROJECT_VERSION` dans `project.yml` pour chaque nouvel envoi, puis :

```bash
xcodegen generate
xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath Artifacts/MangaFlow.xcarchive -derivedDataPath DerivedDataRelease archive
xcodebuild -exportArchive -archivePath Artifacts/MangaFlow.xcarchive \
  -exportPath Artifacts/TestFlight \
  -exportOptionsPlist Deployment/ExportOptions-TestFlight.plist
```

Le profil et le certificat doivent être installés sur le Mac. Le profil est affecté uniquement à la cible application, pour ne pas imposer un profil aux ressources de ZIPFoundation.

## Envoyer et distribuer

Installer `Scripts/requirements-deployment.txt` dans un environnement Python, puis :

```bash
python Scripts/testflight.py --credentials /chemin/prive/release.json --upload --build 1
```

Le script vérifie la fiche app, crée ou retrouve le groupe interne, exige que son unique membre soit l'adresse prévue, envoie l'IPA, attend le traitement Apple et affecte le build au groupe. Les opérations ne soumettent rien à la revue App Store ou à une bêta externe.

Après un envoi déjà réussi, relancer **sans `--upload`** pour reprendre l'attente et l'affectation du même build. `--configure-only` prépare et vérifie le groupe sans envoyer de binaire.

Les résultats détaillés restent locaux dans `Artifacts/testflight-status.json`, `Artifacts/testflight-configuration.json` et `Artifacts/testflight-upload.log`. L'archive et l'IPA ne sont pas versionnés. Les fichiers manga de test ne sont jamais intégrés à l'application.
