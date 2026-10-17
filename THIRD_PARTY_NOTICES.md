# Composants tiers

## Modèle de détection

- Auteur / dépôt : leoxs22 — https://huggingface.co/leoxs22/manga-panel-detector-yolo26n
- Révision source : `40a2854663d537563cfb95c370288a84c6505b9a`.
- Poids source : `manga_panel_detector_fp32.pt`.
- Licence déclarée par la fiche actuelle du modèle : AGPL-3.0, sur base Ultralytics YOLO26.
- Données d'entraînement déclarées : Manga109-s. Aucune image ni annotation de ce dataset n'est incluse ici.
- Export avec Ultralytics 8.4.180, coremltools 9.0, FP32, entrée 640×640 ; poids exportés inclus dans `MangaFlow/Models/PanelDetector.mlpackage`.
- Outils : https://github.com/ultralytics/ultralytics et https://github.com/apple/coremltools.

Ce dépôt est un prototype pour usage personnel. L'utilisateur a confirmé avoir obtenu l'autorisation du créateur de Chika. Cela est enregistré comme contexte du projet ; ce document ne prétend pas modifier les licences des autres auteurs. Ne pas présenter les poids comme Apache-2.0 : la fiche amont a corrigé cette mention en septembre 2026.

## ZIPFoundation

Thomas Zoechling et contributeurs, version 0.9.20, licence MIT.
Source et texte de licence : https://github.com/weichsel/ZIPFoundation/blob/0.9.20/LICENSE
La dépendance est résolue par Swift Package Manager avec version et révision verrouillées.

## Chika

Référence fonctionnelle : https://github.com/batunii/chika (code annoncé MPL-2.0).
Le code de l'application Swift est une implémentation indépendante ; aucun nom, logo, police ou asset de marque de Chika n'a été repris.

## Chapitre de test

Le CBZ de l'utilisateur reste local dans le dossier ignoré `Fixtures/`. Les captures et rapports de diagnostic sont dans `Artifacts/`, également ignoré. Ils ne sont ni intégrés à l'app ni envoyés à un service de traitement.
