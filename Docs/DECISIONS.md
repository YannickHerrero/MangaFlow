# Prototype MangaFlow

- Usage personnel, autorisation du créateur de Chika confirmée par l'utilisateur.
- iOS 27+, SwiftUI, traitement local, modèle embarqué, aucun serveur ni API.
- CBZ contenant JPEG/PNG/WebP (ajout WebP après inspection du chapitre 1196). Aucun fichier manga n'est ajouté à Git.
- Les sources sont conservées ; le manifeste contient les rectangles normalisés (origine haut gauche), l'ordre, les scores et la version du moteur.
- Premier moteur : YOLO26n manga, export Core ML FP32 depuis les poids officiels. Le premier essai FP16 a montré des écarts de détection sur le chapitre ; privilégier la fidélité pour ce prototype.
- Une page dont la détection échoue reste consultable. Aucune promesse de détection parfaite.
- Conversion au premier plan, checkpoint après chaque page, reprise après suspension.
- Référence : https://github.com/batunii/chika (MPL-2.0). Implémentation Swift indépendante.
- Poids : https://huggingface.co/leoxs22/manga-panel-detector-yolo26n, révision 40a2854663d537563cfb95c370288a84c6505b9a (AGPL-3.0 déclarée par l'auteur ; entraînement Manga109-s). Pas de redistribution publique prévue.
