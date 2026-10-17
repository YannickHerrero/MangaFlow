# Développement

Commandes à exécuter depuis la racine du dépôt. Prérequis : Xcode 27+ et un simulateur iOS 27.

## Tests

```bash
xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow \
  -destination 'platform=iOS Simulator,name=MangaFlow-Test' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Les tests unitaires construisent leurs propres images et archives. Le test UI utilise un CBZ privé optionnel placé dans `/private/tmp/mangaflow-ui-fixture.cbz` ; en son absence il est explicitement ignoré. Pour le chapitre utilisé pendant le développement :

```bash
bash Scripts/test.sh '/chemin/vers/Chapitre 1196.cbz'
```

`MANGAFLOW_SIMULATOR` permet de préciser l'UDID du simulateur. Le script utilise par défaut celui créé pendant le développement ; sur un autre Mac utiliser la commande Xcode ci-dessus ou modifier cette variable.

## Organisation

- `Core/DocumentStore.swift` : import ZIP et persistance atomique.
- `Core/LocalPanelDetector.swift` : prétraitement 640×640, Core ML, retour aux coordonnées source.
- `Core/PanelLayout.swift` : dédoublonnage, ordre par séparations de mise en page, marges et préservation des zones de texte détectées.
- `Core/ContourRefiner.swift` : recherche locale des bordures obliques et construction des polygones, avec repli rectangulaire.
- `Core/ConversionEngine.swift` : orchestration et checkpoints.
- `Core/PageImage.swift` : décodage borné et cache mémoire des recadrages.
- `UI/` : bibliothèque, progression et lecteur.
- `project.yml` : source XcodeGen du projet (le projet généré est versionné).

## Modèle et limites

YOLO26n spécialisé manga, export Core ML FP32, environ 9,3 Mo. Ses rectangles sont affinés par une recherche géométrique des bordures inclinées. Les polygones masquent les pixels extérieurs sans redresser ni déformer le dessin. Une bordure trop ambiguë conserve le rectangle initial. Les bords ouverts, dessins qui débordent, bulles partagées et mises en page imbriquées peuvent encore donner des recadrages ou un ordre imparfaits. Les gouttières noires ne sont pas prises en charge par cet affinage : il recherche un trait sombre bordé d'une gouttière claire. Le traitement des doubles pages utilise les cases détectées et les séparations de mise en page ; il ne coupe pas systématiquement l'image en deux.

Pas d'éditeur manuel, OCR, traduction, CBR/PDF, export webtoon ni synchronisation. La position est conservée à la case près, sans décalage précis à l'intérieur d'une grande case. Les recadrages sont calculés à la demande et gardés en cache mémoire, sans copie disque supplémentaire.

Les mesures de validation et les limites observées sont dans [VALIDATION.md](VALIDATION.md).

## Reproduire l'export (facultatif)

Installer `Scripts/requirements-model.txt` dans un environnement Python 3.9 compatible, placer les poids officiels dans `/tmp/manga_panel_detector_fp32.pt`, puis exécuter `python Scripts/export_model.py`. Les coordonnées de sortie attendues sont `[1, 300, 6]` : x1, y1, x2, y2, score, classe.

Provenance et licences : voir [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). Le code et le modèle exporté sont publiés sous **AGPL-3.0** ; voir [LICENSE](../LICENSE). ZIPFoundation conserve sa licence MIT. Chika est une référence fonctionnelle ; l’application Swift est une implémentation indépendante.
