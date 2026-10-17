# Démonstration sur une page de ONE PIECE

Le README compare une page de manga avec son affichage après conversion dans MangaFlow. La page est extraite du même CBZ que celui utilisé pour les essais du prototype.

## Source et crédits

- Œuvre : **ONE PIECE**, par **Eiichiro Oda**, publiée au Japon par **Shueisha**.
- Source matérielle : fichier local fourni par l’utilisateur, `Chapitre 1196.cbz`, douzième image dans l’ordre de lecture (`page-00011.webp` dans les fichiers de travail).
- Le nom du CBZ est le repère utilisé pour les tests. L’en-tête de sa page d’ouverture indique le chapitre **1186** : le nom de l’archive et le numéro imprimé diffèrent.
- Version française telle qu’elle figure dans le fichier fourni ; traducteur et provenance éditoriale de cette version non identifiés.
- Une seule page est publiée pour illustrer le fonctionnement du convertisseur. Le chapitre complet reste local et n’est pas intégré à l’application.

Les dessins, personnages et textes appartiennent à leurs ayants droit. La page source et le montage qui la reproduisent **ne sont pas placées sous AGPL-3.0** ; cette licence concerne le logiciel, pas les droits sur le manga. MangaFlow n’est pas affilié à l’auteur ou à l’éditeur.

## Images et protocole

- `source-page.png` : la douzième page du CBZ, convertie de WebP en PNG sans modification du dessin.
- `vertical-page.png` : les **sept cases** assemblées verticalement, à largeur constante et sans espacement ajouté, sur une image de 900 × 10 272 pixels.
- `conversion.json` : dimensions, ordre, rectangles et contours de cette seule page, calculés par le convertisseur natif iOS (`yolo26-fp32-contours-v2`).

Le montage est rendu par `Scripts/render_demo.py` à partir du manifeste natif. Il conserve l’ordre et les proportions des régions, applique les masques de contours et leurs protections de texte, puis assemble les images sur fond noir comme le lecteur. Les coordonnées ne sont pas choisies à la main. Il s’agit d’un rendu statique de toute la conversion, sans interface du simulateur. Le redimensionnement et la rastérisation du masque sont réalisés avec Pillow ; ce fichier n’est pas une capture UIKit pixel pour pixel.

## Reproduire le montage

À partir du manifeste de démonstration déjà fourni, avec Python et Pillow :

```bash
python3 -m venv .venv
.venv/bin/pip install Pillow
.venv/bin/python Scripts/render_demo.py
```

Pour recalculer aussi la détection avec l’application dans un simulateur iPhone démarré, avec Xcode 27+ :

```bash
MANGAFLOW_SIMULATOR='<UDID du simulateur>' MANGAFLOW_PYTHON='.venv/bin/python' bash Scripts/capture_demo.sh
```

Le script prépare un CBZ temporaire d’une seule page et lance son import dans l’application via XCTest. Il exporte le manifeste natif de cette conversion puis reconstruit l’image verticale. Les pièces jointes et résultats XCTest restent dans `Artifacts/`, ignoré par Git. Le CBZ temporaire est supprimé à la fin.

Pour tester manuellement la même page :

```bash
python3 - <<'PY'
from zipfile import ZipFile
with ZipFile('/tmp/MangaFlow-demo.cbz', 'w') as archive:
    archive.write('Docs/demo/source-page.png', '001.png')
PY
```

Transférer ce CBZ vers l’iPhone puis l’ouvrir dans MangaFlow.
