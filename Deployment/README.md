# TestFlight privé

## Mise à jour immersive — build 2

Le 17 octobre 2026, **0.1.0 (2)** a été validé par Apple et affecté au même groupe interne, avec exactement un testeur. États confirmés : **INTERNAL_ONLY** et **IN_BETA_TESTING**. Les 17 tests passent, dont le parcours de lecture immersive sur le chapitre 1196. La signature de l’archive a été vérifiée. Aucun nouvel envoi d’invitation n’était nécessaire.

Nouveautés : cases sans espacement ajouté, suppression des repères et du compteur de pages, commandes masquables avec le bouton œil et réaffichables par double toucher. Le simple toucher conserve l’accès à l’original.

## Première livraison terminée

Le 17 octobre 2026, la version **0.1.0 (1)** a été signée, exportée puis envoyée avec succès. Apple a validé le build et confirme **INTERNAL_ONLY** / **IN_BETA_TESTING**. Il est affecté au groupe ci-dessous avec exactement un testeur. La demande d'envoi de l'invitation à `yannick.herrero@proton.me` a été acceptée par Apple. Aucun groupe externe ni lien public n'a été créé.

Accès : https://appstoreconnect.apple.com/apps/6824043882/testflight/ios

Les 17 tests ont été réexécutés avec le Bundle ID de distribution et passent. La signature de l'archive a été vérifiée avec `codesign --verify --deep --strict`. Le manifeste de confidentialité couvre les préférences locales et la vérification de l'espace disque ; l'app déclare ne pas utiliser de chiffrement non exempté.

Sur iPhone sous iOS 27 ou plus récent : ouvrir l'invitation Apple, accepter avec TestFlight et installer **MangaFlow reader**. La fiche App Store Connect a été créée manuellement par l'utilisateur ; les opérations suivantes ont été réalisées via la clé API existante.

## Configuration

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
python Scripts/testflight.py --credentials /chemin/prive/release.json --upload --build 2 \
  --notes-file Deployment/build2-notes.fr.txt
```

Le script vérifie la fiche app, crée ou retrouve le groupe interne, exige que son unique membre soit l'adresse prévue, envoie l'IPA, attend le traitement Apple, vérifie l'audience interne et affecte le build au groupe. `--notes-file` fournit les nouveautés en français. `--invite` demande explicitement l'envoi de l'invitation au seul testeur. Les opérations ne soumettent rien à la revue App Store ou à une bêta externe.

Après un envoi déjà réussi, relancer **sans `--upload`** pour reprendre l'attente et l'affectation du même build. `--configure-only` prépare et vérifie le groupe sans envoyer de binaire.

Les résultats détaillés restent locaux dans `Artifacts/testflight-status.json`, `Artifacts/testflight-configuration.json` et `Artifacts/testflight-upload.log`. L'archive et l'IPA ne sont pas versionnés. Les fichiers manga de test ne sont jamais intégrés à l'application.
