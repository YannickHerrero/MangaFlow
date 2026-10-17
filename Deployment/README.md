# TestFlight privé

## Trois thèmes et bibliothèque par série — build 6

Le 18 octobre 2026, **0.1.0 (6)** a été validé par Apple et affecté au groupe interne **Yannick — Personnel**, avec exactement un testeur. États confirmés : **VALID**, **INTERNAL_ONLY**, **IN_BETA_TESTING** ; lien public désactivé. Identifiant du build : `3d41b797-ad8b-4016-9c58-842225c6a196`.

Nouveautés : thèmes Holographique, Brutaliste et Planche manga en clair/sombre/système, tab bars personnalisées, navigation Bibliothèque / Explorer / Activité, séries liées aux identifiants des sources, couvertures AniList corrigibles avec cache, favoris de sources, filtres et états de lecture, suivi des transferts avec progression/annulation et lecture du chapitre local suivant. La règle conservant les pages composées uniquement de cases pleine largeur est incluse. Appairage et fichiers locaux conservés.

Validation : 40 tests unitaires Swift et neuf tests serveur, captures et parcours des six variantes sur simulateurs iPhone et iPad, sélection du thème conservée après relancement, lecture du CBZ privé et reprise, Blue Lock / LELScan 364.1 (neuf pages) et 363 (20 pages) téléchargés/importés dans une seule série, et lecture avec le serveur réellement arrêté. Signature de l’archive vérifiée avec `codesign --verify --deep --strict`. Le serveur a été relancé après le contrôle hors ligne. [Architecture, migration et limites](../Docs/THEMES_AND_LIBRARY.md).

## Favoris et suivi des téléchargements — build 5

Le 17 octobre 2026, **0.1.0 (5)** a été validé par Apple et affecté au groupe interne existant : **INTERNAL_ONLY**, **IN_BETA_TESTING**, un seul testeur. L’appairage et la bibliothèque existants sont conservés.

Cette version ajoute l’onglet Favoris (manga lié à son serveur et sa source exacts), le cœur dans les chapitres, ainsi que les états de téléchargement, la progression, les erreurs avec nouvelle tentative et l’action Importer et lire directement dans chaque chapitre. Validation : 25 tests unitaires Swift, parcours Blue Lock / LELScan avec téléchargement réel de neuf images, persistance du favori après relancement et ouverture du lecteur, plus le test de non-régression du lecteur existant.


## Sources en ligne — build 4

Le 17 octobre 2026, **0.1.0 (4)** a été validé par Apple et affecté au groupe interne existant, limité à un testeur. États confirmés : **INTERNAL_ONLY** et **IN_BETA_TESTING**. L’archive a été signée et sa signature vérifiée. Cette version ajoute l’onglet Sources, l’appairage QR sur le réseau local et l’import de chapitres téléchargés par le serveur Mac HakuNeko. Aucun App Store public ni nouveau groupe n’a été créé.

Le serveur Mac doit fonctionner sur le même réseau que l’iPhone/iPad. Démarrage et appairage : [Server/README.md](../Server/README.md). Validation réelle et limites : [Docs/ONLINE_SOURCES.md](../Docs/ONLINE_SOURCES.md).


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
