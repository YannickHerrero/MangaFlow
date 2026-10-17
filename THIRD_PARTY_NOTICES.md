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

`Docs/demo/source-page.png` reproduit une seule page de **ONE PIECE**, par **Eiichiro Oda**, publié au Japon par **Shueisha**. Elle provient du fichier local `Chapitre 1196.cbz` fourni par l’utilisateur, dont la page d’ouverture indique le chapitre 1186. Les captures `demo-reader-*.png` montrent le traitement réel de cette même page par MangaFlow. La source et le protocole sont documentés dans [Docs/demo/README.md](Docs/demo/README.md).

Les dessins, personnages et textes restent la propriété de leurs ayants droit. L’extrait et les captures qui le reproduisent sont exclus de la licence AGPL-3.0 du logiciel. Le CBZ complet n’est pas publié. Aucune affiliation à l’auteur ou à l’éditeur n’est revendiquée.
