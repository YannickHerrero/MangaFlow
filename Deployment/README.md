# TestFlight privé

## Début du chapitre suivant et pages originales — build 12

Le 18 octobre 2026, **0.1.0 (12)** a été confirmé **VALID**, **INTERNAL_ONLY**, **IN_BETA_TESTING**, affecté au même groupe privé à un seul testeur, sans lien public. Identifiant : `cd9c529f-808d-4275-a074-760fb83bda57`.

Le bouton Chapitre suivant ouvre explicitement le début du document cible, avec remise à zéro persistée de sa position et de son état terminé. L’ouverture normale conserve la reprise. L’identité du lecteur dépend du document pour empêcher la réutilisation de la position du chapitre précédent. Le bouton Pages originales, dans l’en-tête, affiche les pages entières en défilement continu sans masque ni espacement ajouté. Il conserve la page courante au changement de mode, mémorise le choix et réutilise le zoom original existant.

Validation : 56 tests unitaires réussis (deux revues privées supplémentaires ignorées dans la suite courante), plus deux parcours UI réussis sur iPhone : chapitre suivant déjà terminé ouvrant à la page 1, bascule de mode avec maintien de la page, absence d’espacement, zoom et réouverture. Le mode a aussi été testé sur un chapitre réel importé. Fixtures locales de contrôle nettoyées après les tests. Archive signée, signature vérifiée, export et disponibilité TestFlight privée confirmés. Le serveur Mac répond après la livraison.

## Chapitres récents en premier — build 11

Le 18 octobre 2026, **0.1.0 (11)** a été confirmé **VALID**, **INTERNAL_ONLY**, **IN_BETA_TESTING**, affecté au groupe privé à un seul testeur et sans lien public. Identifiant : `8e51ee22-cb3b-42c6-80b3-c8d91cecb52a`.

Ce build réunit le regroupement par colonne, la correction de l’espace réservé à la tab bar du build 10 et le tri de la fiche manga du plus récent au plus ancien (310 avant 309). Le tri de présentation est séparé de l’ordre de lecture utilisé pour le chapitre suivant. Les titres non numériques conservent l’ordre de catalogue fourni par la source ; un classement manuel utilise son ordre explicite, décroissant à l’affichage.

Validation : 55 tests automatisés réussis, dont tri naturel, classement manuel, titres non numériques et conservation de l’ordre chronologique de lecture. Deux tests de revue privée ignorés dans la suite courante. Contrôles de la tab bar sur iPhone et iPad effectués pour le même changement dans le build 10. Archive signée, signature vérifiée et export terminé avant envoi ; disponibilité privée confirmée par Apple.

## Regroupement par colonne et espace sous la navigation — build 10

Le 18 octobre 2026, **0.1.0 (10)** a été confirmé **VALID**, **INTERNAL_ONLY**, **IN_BETA_TESTING** dans le groupe privé à un seul testeur, sans lien public. Identifiant : `9cf43a05-195d-4a54-bbab-24bfdb1522f0`.

Les piles de cases alignées sont regroupées lorsqu’une grande case voisine établit une disposition en colonnes. La page 16 de Blue Lock 310 reproduit exactement l’aperçu validé. Le moteur v5 reconvertit les anciens chapitres à leur ouverture. La tab bar occupe désormais un espace réservé en dehors des NavigationStack ; les zones défilantes s’arrêtent au-dessus de la barre.

Les changements sont dans des commits distincts : colonnes `3260771`, tab bar `6494d99`. Validation : 54 tests automatisés, deux revues privées exécutées explicitement (page 16 du chapitre 310 et chapitre 309 complet), contrôle des trois thèmes et des limites des zones défilantes sur simulateurs iPhone et iPad, avec portrait et paysage sur iPad. Les deux tests privés sont ignorés dans les suites courantes. Archive signée et vérifiée. L’envoi était déjà commencé au moment de la demande de tri des chapitres ; ce tri est inclus dans le build suivant.

## Bandes pleine largeur et masques inclinés — build 9

Le 18 octobre 2026, **0.1.0 (9)** a été validé par Apple et affecté au même groupe privé à un seul testeur : **VALID**, **INTERNAL_ONLY**, **IN_BETA_TESTING**, lien public désactivé. Identifiant : `0d325c86-46cd-482d-9a1a-5360a20ff231`.

Les bandes pleine largeur inclinées restent entières ; les suites de bandes sont regroupées dans les pages mixtes, sans fusionner les cases incrustées. Les masques suivent des diagonales plus prononcées et des jonctions convexes en pointe. Les grands bandeaux de narration détectés hors cadre sont conservés. Le moteur v4 reconvertit les anciens chapitres à leur ouverture. Les compositions très imbriquées restent imparfaites.

Validation : cinq itérations et revue des 19 pages du chapitre privé Blue Lock 309 (LELScan), comparatifs approuvés par l’utilisateur avant publication. 52 tests automatisés réussis ; le test de revue privée supplémentaire a été exécuté explicitement puis désactivé dans la suite courante (53 tests dont un ignoré). Archive signée, signature vérifiée, export et disponibilité TestFlight confirmés. Les images privées et comparatifs restent dans les dossiers ignorés par Git.

## Téléchargement et import en une action — build 8

Le 18 octobre 2026, **0.1.0 (8)** a été validé par Apple et affecté au groupe privé existant, avec un seul testeur (**INTERNAL_ONLY**, **IN_BETA_TESTING**, aucun lien public). Identifiant : `4a3126c9-2111-4756-907e-569c8a6f4ee1`.

Télécharger un chapitre depuis Explorer programme désormais son transfert et son import automatiques dans la bibliothèque. Les demandes sont conservées avant la réponse du serveur et reprises au retour dans l’app. Les imports sont traités un par un et attendent si une conversion est déjà en cours. Le lecteur ne s’ouvre pas automatiquement : le bouton devient Lire quand le chapitre est disponible localement. Une erreur propose une nouvelle tentative ; une annulation explicite retire la demande automatique. La nouvelle icône LIRE du build 7 est incluse.

Validation : 47 tests unitaires Swift, dont persistance/isolation des demandes, récupération après réponse manquante, attente d’une bibliothèque occupée, absence de doublons/ouverture du lecteur et comptage des transferts. Parcours réel LELScan / Blue Lock 362 : un seul appui Télécharger, import automatique, maintien dans Explorer, puis lecture après relancement. Archive signée, vérifiée et exportée avant envoi.

## Nouvelle icône — build 7

Le 18 octobre 2026, **0.1.0 (7)** a été validé par Apple et affecté au même groupe privé à un seul testeur (**INTERNAL_ONLY**, **IN_BETA_TESTING**, lien public désactivé). Identifiant : `43603d48-38a4-4f45-bc51-2bdeedbe8118`. L’icône utilise l’image originale carrée LIRE fournie par l’utilisateur, redimensionnée de 1254 à 1024 pixels, sans transparence et sans recadrage. Archive signée, vérifiée et exportée avec succès.

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
