# Démonstration publique

Cette planche a été créée spécialement pour illustrer MangaFlow. Elle ne provient ni d’un manga commercial ni du chapitre privé utilisé pendant le développement.

- `source-page.png` : image source originale, générée avec l’outil intégré `imagegen`.
- `demo-reader-start.png` : capture réelle du début de la lecture immersive.
- `demo-reader-scroll.png` : capture réelle après défilement dans le même document.

Les captures sont produites par l’application SwiftUI dans le simulateur iOS 27, après import d’un CBZ d’une page, détection Core ML et ordonnancement des cases. Les images du lecteur ne sont pas des maquettes. Sur cette planche, le modèle a détecté quatre cases, lues de droite à gauche puis de haut en bas. Aucune région n’est saisie à la main. Le modèle s’exécute localement ; la génération de l’illustration est uniquement une étape de préparation de cette documentation.

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

## Prompt de l’illustration

Outil utilisé : génération d’image intégrée `imagegen`, sans image de référence.

> Create one original black and white manga comic page for an open source iPhone reader demo. Portrait page 1024x1536. Exactly FOUR distinct large comic panels arranged two rows of two panels, wide white gutters and crisp black rectangular borders, simple Japanese manga reading order right to left. Wholesome original story: a young courier wearing a scarf and round goggles discovers a tiny friendly robot in a rain-soaked rooftop garden and shelters it under an umbrella. Top right establishing panel rooftop futuristic city with courier approaching; top left closeup of the small robot beside a plant; bottom right courier opening umbrella toward robot; bottom left both sitting beneath umbrella with distant city lights. Consistent original characters, refined ink linework, halftone shading, visually rich manga artwork, no franchise characters, no lettering, no text, no speech bubbles, no watermarks, no captions. Each drawing entirely confined to its own rectangular panel. No additional inset panels, no title strip. Clean white page margin.
