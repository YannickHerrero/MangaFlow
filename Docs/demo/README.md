# Démonstration sur une page de ONE PIECE

Le README compare une page de manga avec son affichage après conversion dans MangaFlow. La page est extraite du même CBZ que celui utilisé pour les essais du prototype.

## Source et crédits

- Œuvre : **ONE PIECE**, par **Eiichiro Oda**, publiée au Japon par **Shueisha**.
- Source matérielle : fichier local fourni par l’utilisateur, `Chapitre 1196.cbz`, sixième image dans l’ordre de lecture (`page-00005.webp` dans les fichiers de travail).
- Le nom du CBZ est le repère utilisé pour les tests. L’en-tête de sa page d’ouverture indique le chapitre **1186** : le nom de l’archive et le numéro imprimé diffèrent.
- Version française telle qu’elle figure dans le fichier fourni ; traducteur et provenance éditoriale de cette version non identifiés.
- Une seule page est publiée pour illustrer le fonctionnement du convertisseur. Le chapitre complet reste local et n’est pas intégré à l’application.

Les dessins, personnages et textes appartiennent à leurs ayants droit. La page source et les captures qui la reproduisent **ne sont pas placées sous AGPL-3.0** ; cette licence concerne le logiciel, pas les droits sur le manga. MangaFlow n’est pas affilié à l’auteur ou à l’éditeur.

## Images et protocole

- `source-page.png` : la sixième page du CBZ, convertie de WebP en PNG sans modification du dessin.
- `demo-reader-start.png` : capture réelle du début de la lecture immersive de cette page.
- `demo-reader-scroll.png` : capture réelle après défilement dans le même document.

Les captures sont produites par l’application SwiftUI dans le simulateur iOS 27, après import d’un CBZ contenant uniquement cette page, détection Core ML et ordonnancement des cases. Quatre cases sont détectées automatiquement sur cette page. Aucune région n’est saisie à la main. Les captures ne sont pas des maquettes et les recadrages affichés ne sont pas retouchés. Le modèle s’exécute localement.

## Reproduire les captures

Avec Xcode 27+, un simulateur iPhone démarré et ce dépôt cloné :

```bash
MANGAFLOW_SIMULATOR='<UDID du simulateur>' bash Scripts/capture_demo.sh
```

Le script prépare un CBZ temporaire à partir de la seule image publique, lance le parcours de capture XCTest puis copie les deux pièces jointes dans ce dossier. Les résultats XCTest restent dans `Artifacts/`, ignoré par Git. Le CBZ temporaire est supprimé à la fin. Aucune modification des préférences ou des documents de l’appareil physique n’est nécessaire.

Pour tester manuellement la même page :

```bash
python3 - <<'PY'
from zipfile import ZipFile
with ZipFile('/tmp/MangaFlow-demo.cbz', 'w') as archive:
    archive.write('Docs/demo/source-page.png', '001.png')
PY
```

Transférer ce CBZ vers l’iPhone puis l’ouvrir dans MangaFlow.
