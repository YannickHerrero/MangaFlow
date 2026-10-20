# MangaFlow

[English](README.md)

Transformez vos mangas CBZ en lecture verticale, façon webtoon, sur iPhone et iPad. La détection des cases fonctionne entièrement sur l’appareil avec Core ML. La lecture des CBZ locaux ne nécessite aucun serveur ni compte.

## Avant / après

<table>
  <tr><th>Page originale</th><th>Lecture verticale</th></tr>
  <tr>
    <td width="50%" valign="top"><a href="Docs/demo/source-page.png"><img src="Docs/demo/source-page.png" alt="Page originale de ONE PIECE par Eiichiro Oda" width="420"></a></td>
    <td width="50%" valign="top"><a href="Docs/demo/vertical-page.png"><img src="Docs/demo/vertical-page.png" alt="Les sept cases assemblées verticalement dans l’ordre de lecture" height="600"></a></td>
  </tr>
</table>

Une page, sept cases extraites automatiquement. Cliquez sur une image pour l’afficher en grand. Dessins : **ONE PIECE — Eiichiro Oda / Shueisha**. [Détails et crédits de la démo](Docs/demo/README.md).

## Fonctionnalités

- Import de CBZ contenant des images JPEG, PNG ou WebP depuis Fichiers ou iCloud Drive.
- Défilement vertical continu des cases, avec prise en charge des bordures inclinées.
- Commandes masquables pour une lecture immersive ; toucher à deux doigts pour les réafficher.
- Simple toucher pour ouvrir la page originale et zoomer.
- En mode pages originales, toucher un dialogue pour un zoom modéré, puis utiliser la flèche du bas pour suivre les textes dans l’ordre de lecture. Le bouton reste fixé en bas de l’écran ; chaque nouvelle page commence en vue d’ensemble. Les réglages permettent d’ajuster la taille des dialogues et le zoom maximal. L’ordre géométrique peut rester imparfait sur les compositions atypiques.
- Reprise des conversions et mémorisation de la position de lecture.
- Favoris liés à leur source et suivi des téléchargements directement dans les chapitres.

L’ordre manga va de droite à gauche par défaut, avec une option gauche à droite.

Une interface claire/sombre, des couvertures AniList facultatives et une navigation large Liquid Glass Bibliothèque / Explorer. L’historique reste conservé après suppression locale des chapitres. [Détails](Docs/REDESIGN.md).

## Sources en ligne

Parcourez des sources HakuNeko via un Mac sur le même réseau local. Appairez par QR code, téléchargez les chapitres sur le Mac, puis importez-les pour les lire hors ligne sur iPhone ou iPad. [Installer le serveur Mac](Server/README.md).

## Essayer

Nécessite **iOS 27+** et **Xcode 27+**.

1. Ouvrir `MangaFlow.xcodeproj` dans Xcode.
2. Sélectionner la cible **MangaFlow**, choisir son équipe de signature et définir un identifiant de bundle unique.
3. Lancer sur un iPhone ou un simulateur iOS, puis importer un fichier `.cbz`.

Le modèle est inclus dans l’application. Internet est nécessaire pour la première résolution des dépendances Xcode ; lecture et conversion fonctionnent ensuite hors ligne. Garder l’application au premier plan pendant la conversion. L’interface est actuellement en français.

C’est un prototype : la détection et l’ordre des cases peuvent être imparfaits. [Guide de développement](Docs/DEVELOPMENT.md) · [Validation et limites](Docs/VALIDATION.md) · [Composants tiers](THIRD_PARTY_NOTICES.md).

## Licence

[AGPL-3.0](LICENSE). Les dessins de la démo appartiennent à leurs ayants droit et sont exclus de cette licence.
