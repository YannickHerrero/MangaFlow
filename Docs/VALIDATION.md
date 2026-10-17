# Validation du prototype — 17 octobre 2026

## Mise à jour : contours inclinés (v2)

- Détecteur inchangé ; ajout d'un affinage géométrique local, sans dépendance ni serveur supplémentaire.
- Polygones dans les coordonnées de la page, masque alpha transparent, aucune rotation ou déformation du dessin.
- Conservation par union des rectangles de texte attribués à la case. Les textes non détectés ne bénéficient pas de cette protection.
- Repli rectangulaire si aucun bord incliné assez fiable n'est trouvé ou si la coupe retirerait plus de 40 % de l'aire du rectangle.
- Le moteur recherche des traits sombres avec une gouttière claire ; les gouttières noires et contours courbes restent hors périmètre.
- Mise à jour des anciens manifests au prochain lancement de leur conversion ; décodage des manifests v1 conservé.
- Sur le chapitre 1196 : **101 régions conservées, 24 avec un contour polygonal**, une couverture entière. Environ **6,42 secondes** de traitement des pages dans le simulateur en Debug (cette mesure v2 remplace la durée v1 ci-dessous pour la version actuelle).
- Comparatifs avant / après inspectés, notamment les cases des pages 4, 5 et 6 où les bandes de cases voisines sont retirées. Les comparatifs sont générés à partir du manifeste de l'application ; les tests de pixels vérifient aussi le rendu alpha natif UIKit.
- **16 tests unitaires + 1 test UI, zéro échec**, compilation Release pour iPhone réussie sans signature. Les nouveaux tests couvrent l'orientation du bitmap d'analyse, les bordures inclinées, le repli sur image sans cadre / cadre droit, la transparence et les textes protégés, la compatibilité du manifeste et la migration d'une ancienne conversion.
- Le test de charge 200 pages ci-dessous correspond à la v1 ; il n'a pas été remesuré pour la v2. Aucune mesure sur iPhone physique.

Comparatifs privés : `Artifacts/contours/5-0.jpg` et `Artifacts/contours/5-2.jpg`. Planche des contours : `Artifacts/native-layouts-v2/contact-sheet.jpg`. Les masques peuvent être désactivés dans le menu du lecteur pour comparer avec les rectangles.

Les sections suivantes décrivent la validation initiale de la v1.

## Résultat

- Build Debug pour simulateur iOS 27 : réussi.
- Build Release arm64 pour iPhone / iOS 27.1 SDK : réussi, sans signature (`CODE_SIGNING_ALLOWED=NO`). Taille du bundle : environ 11 Mo.
- Suite finale : **10 tests unitaires + 1 test d'interface, zéro échec et zéro test ignoré**.
- Test UI : import du CBZ privé, ouverture automatique du lecteur, deux défilements, consultation de l'original, fermeture, arrêt de l'app, relancement et vérification de la même page / case.
- Les essais automatisés utilisent une injection de fichier en Debug pour démarrer l'import. Le choix du fichier dans le sélecteur iCloud natif n'a pas été automatisé.
- Aucun iPhone physique connecté pendant cette validation : pas de mesure sur appareil réel et pas d'installation signée effectuée.

## Chapitre 1196

CBZ fourni par l'utilisateur, 11,2 Mo, 16 images WebP, dont une double page. Aucune image de ce fichier n'est versionnée ou envoyée à un serveur de traitement.

| Mesure | Résultat |
| --- | --- |
| Pages traitées | 16 / 16 |
| Régions de lecture | 101 |
| Pages en repli pleine page | 1 (couverture) |
| Images illisibles | 0 |
| Somme des temps d'analyse des pages | environ 1,26 s |

Ce temps couvre le décodage de travail, la détection et la construction des régions ; il ne représente pas la durée complète depuis l'ouverture du sélecteur iCloud. Mesures en Debug sur le simulateur iOS 27, calcul CPU sur le Mac.

Des planches de diagnostic numérotées ont été inspectées pour vérifier les recadrages et l'ordre général, y compris la double page. Cela ne constitue pas une évaluation annotée de précision à 95 % : les taux d'extraction, d'ordre exact et de préservation des dialogues ne sont pas encore quantifiés sur un corpus indépendant.

## Charge de 200 pages

Archive synthétique de 200 pages obtenue en répétant les pages du chapitre, pour vérifier le fonctionnement sur un volume plus long. Ce n'est pas un corpus de 200 pages indépendantes.

| Mesure | Résultat |
| --- | --- |
| Pages traitées | 200 / 200 |
| Régions de lecture | 1 255 |
| Temps total, lancement / import / conversion inclus | 15,33 s |
| Somme des temps d'analyse | 14,10 s |
| Maximum RSS échantillonné | environ 327 Mio |

Le maximum RSS est échantillonné toutes les 250 ms, pas mesuré avec Instruments. Le premier essai avait atteint environ 436 Mio ; l'ajout d'un pool de libération des allocations temporaires autour de chaque détection a abaissé ce maximum. Le cache des recadrages est limité à 48 Mio ; le décodage travaille sur une page à la fois. Le défilement prolongé d'un volume de 200 pages n'a pas fait l'objet d'un profilage de fluidité avec Instruments.

## Modèle

YOLO26n manga, Core ML FP32, entrée 640×640, sortie `[1, 300, 6]`. Modèle d'environ 9,3 Mo, embarqué dans l'application.

L'essai FP16 a montré des différences par rapport aux prédictions PyTorch. FP32 a été retenu pour le prototype, mais les sorties ne sont pas strictement identiques entre les chemins PyTorch, Core ML Python et Core ML Swift, notamment avec des prétraitements / interpolations d'image différents. Les scripts de comparaison restent disponibles ; aucune parité numérique parfaite n'est revendiquée.

Le simulateur force le CPU. Sur iPhone, Core ML peut choisir les unités de calcul disponibles. La vitesse, la mémoire, la chauffe et les différences numériques sur appareil réel restent à mesurer.

## Tests unitaires

1. Import d'une archive construite pendant le test, persistance et refus d'un faux CBZ.
2. Filtrage des chemins d'archive et tri naturel.
3. Chargement du modèle embarqué, conversion et absence de retraitement des pages terminées.
4. Annulation après le premier checkpoint, puis reprise des pages restantes.
5. Extension d'un recadrage pour conserver une zone de texte détectée.
6. Suppression des doublons et rectangles invalides.
7. Préservation d'une petite case imbriquée.
8. Retour des coordonnées letterbox vers la page source, portrait et paysage.
9. Ordre RTL et LTR sur une grille.
10. Ordre d'une grande case longeant plusieurs cases empilées.

## Limites connues

- Recadrages rectangulaires : des fragments de cases voisines peuvent apparaître autour des bordures obliques.
- Les bulles non détectées, partagées ou éloignées d'une case peuvent être tronquées. L'original reste accessible.
- L'ordre de lecture repose sur les séparations et des heuristiques ; il peut être erroné sur des compositions ambiguës.
- Une détection partiellement incorrecte ne déclenche pas toujours le repli pleine page.
- Les doubles pages sont ordonnées par leurs cases et gouttières, sans séparation automatique systématique.
- La position reprend à la case, sans conserver exactement le décalage vertical dans une grande case.
- Conversion au premier plan ; checkpoint après chaque page, reprise manuelle possible après interruption.
- JPEG / PNG / WebP uniquement ; pas de CBR, PDF ou ZIP chiffré.

## Reproduction

- `bash Scripts/test.sh '/chemin/vers/Chapitre 1196.cbz'`
- `python Scripts/benchmark_simulator.py <UDID> '/chemin/vers/Chapitre 1196.cbz'`
- `python Scripts/evaluate_model.py '/chemin/vers/Chapitre 1196.cbz'` (environnement Python du modèle requis).
- `python Scripts/inspect_manifest.py '<CBZ>' 'Artifacts/chapter-1196-manifest.json'`

Les résultats XCTest détaillés sont conservés localement dans `DerivedData/Logs/Test/`. Les manifests, captures et diagnostics privés sont dans `Artifacts/`, ignoré par Git.
