# Composants tiers

## Modèle de détection

- Auteur / dépôt : leoxs22 — https://huggingface.co/leoxs22/manga-panel-detector-yolo26n
- Révision source : `40a2854663d537563cfb95c370288a84c6505b9a`.
- Poids source : `manga_panel_detector_fp32.pt`.
- Licence déclarée par la fiche actuelle du modèle : AGPL-3.0, sur base Ultralytics YOLO26.
- Données d'entraînement déclarées : Manga109-s. Aucune image ni annotation de ce dataset n'est incluse ici.
- Export avec Ultralytics 8.4.180, coremltools 9.0, FP32, entrée 640×640 ; poids exportés inclus dans `MangaFlow/Models/PanelDetector.mlpackage`.
- Outils : https://github.com/ultralytics/ultralytics et https://github.com/apple/coremltools.

Le projet est publié sous AGPL-3.0 ; voir [LICENSE](LICENSE). Le modèle exporté conserve la licence AGPL-3.0 et sa provenance amont. Modification du 17 octobre 2026 : export des poids FP32 PyTorch vers Core ML, sans nouvel entraînement. Le script d’export est dans `Scripts/export_model.py`. L'utilisateur a confirmé avoir obtenu l'autorisation du créateur de Chika. Cela est enregistré comme contexte du projet ; ce document ne prétend pas modifier les licences des autres auteurs. Ne pas présenter les poids comme Apache-2.0 : la fiche amont a corrigé cette mention en septembre 2026.

## ZIPFoundation

Thomas Zoechling et contributeurs, version 0.9.20, licence MIT.
Copie du texte de licence : [Licenses/ZIPFoundation-MIT.txt](Licenses/ZIPFoundation-MIT.txt).
Source et texte de licence : https://github.com/weichsel/ZIPFoundation/blob/0.9.20/LICENSE
La dépendance est résolue par Swift Package Manager avec version et révision verrouillées.

## Chika

Référence fonctionnelle : https://github.com/batunii/chika (code annoncé MPL-2.0).
Le code de l'application Swift est une implémentation indépendante ; aucun nom, logo, police ou asset de marque de Chika n'a été repris.

## Chapitre de test

Le CBZ de l'utilisateur reste local dans le dossier ignoré `Fixtures/`. Les captures et rapports de diagnostic sont dans `Artifacts/`, également ignoré. Ils ne sont ni intégrés à l'app ni envoyés à un service de traitement.

## Extrait de manga utilisé pour la démonstration

`Docs/demo/source-page.png` reproduit une seule page de **ONE PIECE**, par **Eiichiro Oda**, publié au Japon par **Shueisha**. Elle provient du fichier local `Chapitre 1196.cbz` fourni par l’utilisateur, dont la page d’ouverture indique le chapitre 1186. Le montage `Docs/demo/vertical-page.png` assemble les sept cases de cette même page à partir du manifeste calculé par MangaFlow. La source et le protocole sont documentés dans [Docs/demo/README.md](Docs/demo/README.md).

Les dessins, personnages et textes restent la propriété de leurs ayants droit. L’extrait et le montage qui le reproduit sont exclus de la licence AGPL-3.0 du logiciel. Le CBZ complet n’est pas publié. Aucune affiliation à l’auteur ou à l’éditeur n’est revendiquée.

## HakuNeko et serveur facultatif

Source : https://github.com/manga-download/hakuneko — licence Unlicense. Le serveur télécharge le paquet web officiel signé et le conserve hors Git. Aucun fichier amont n’est modifié ; les adaptations sont dans `Server/src/engine`. Audit et version vérifiée : [Docs/ONLINE_SOURCES.md](Docs/ONLINE_SOURCES.md). Le fichier `Server/src/engine/upstream-public.pem` contient uniquement la clé publique de vérification publiée par HakuNeko.

Le serveur utilise Electron (MIT), @electron/remote (MIT), CryptoJS (MIT), JSZip (MIT ou GPL-3.0) et qrcode (MIT). Les versions et intégrités sont verrouillées dans `Server/package-lock.json` ; leurs textes de licence sont fournis dans les paquets installés.

## Typography and optional metadata

The application uses the system font. Previously bundled Google Fonts and the Terminal theme have been removed.

AniList provides optional manga metadata and cover URLs through its public API (https://anilist.co ; https://docs.anilist.co/guide/terms-of-use). Manga covers and metadata are not covered by MangaFlow's AGPL license. They are fetched for the user's selected series and cached locally; none are bundled in the application.

## Balloon and free-text detector

- Author: ogkalu — https://huggingface.co/ogkalu/comic-speech-bubble-detector-yolov8m
- Pinned revision: `21d5af0a9c69bb522b9968d6cc915f898d71a264`.
- Checkpoint: `comic-speech-bubble-detector.pt`, SHA256 `10bc9f702698148e079fb4462a6b910fcd69753e04838b54087ef91d5633097b`.
- The upstream model card declares Apache-2.0 (see `Licenses/BubbleDetector-Apache-2.0.txt`). The checkpoint uses Ultralytics YOLOv8m; the Ultralytics exporter labels its generated package AGPL-3.0. MangaFlow remains AGPL-3.0; this note does not relicense Ultralytics components.
- Upstream describes training on approximately 8,000 manga, webtoon, manhua and western comic images at 1024 pixels. No training images are bundled.
- Local modification: export to Core ML FP16, fixed 1024 × 1024 input, without built-in NMS. Swift postprocessing performs confidence filtering, class-specific NMS and coordinate restoration. No retraining.
- Exported weights are in `MangaFlow/Models/TextDetector.mlpackage` (~50 MiB). Reproduction: `Scripts/export_text_model.py` with `Scripts/requirements-model.txt`.
