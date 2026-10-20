# Interface unifiée — build 16

L’interface reprend la maquette « Application de lecture – Bibliothèque » : fond blanc cassé/noir, police système, listes compactes, couvertures facultatives, boutons ronds et réglages en feuille. Les quatre thèmes précédents et leurs polices sont supprimés. Le choix système/clair/sombre reste mémorisé. À la demande de l’utilisateur, la navigation utilise la barre native Liquid Glass d’iOS 27, avec deux onglets Bibliothèque et Explorer. Il n’y a plus de page Activité.

La bibliothèque sépare les lectures en cours et les groupes par source, propose une recherche, un filtre non lus et un tri titre/récence. La fiche manga conserve le tri des chapitres, le filtre lus, le classement manuel, les métadonnées et les accès aux chapitres de la source. Explorer conserve les favoris et le catalogue ; les téléchargements, leur progression, leur annulation et les reprises d’import restent dans la liste des chapitres. Les imports automatiques continuent à se réconcilier au retour au premier plan. L’appairage et la gestion du Mac se trouvent uniquement dans Réglages → Connexion au Mac.

## Historique et suppression locale

`reading-history.json`, dans le dossier de bibliothèque de l’application, conserve un enregistrement léger de chaque chapitre supprimé : identité serveur/source/manga/chapitre, classement, titre, état terminé et dernière position. Aucune image ni détection n’y est conservée. Une sauvegarde atomique réussie est obligatoire avant la suppression des fichiers ; un historique illisible bloque la suppression pour éviter une perte silencieuse.

« Supprimer les chapitres lus » supprime uniquement les dossiers locaux des chapitres terminés. Les mangas et les couvertures restent dans la bibliothèque. Les chapitres supprimés restent identifiables dans la fiche, sans bouton de lecture locale. Le filtre Explorer utilise l’ensemble des enregistrements, y compris ceux supprimés localement : sa limite numérique reste le plus haut chapitre terminé du même serveur/source/manga, numéro inclus. Un nouvel import depuis la même source restaure l’état et la position du chapitre. Les fichiers et tâches du Mac ne sont jamais supprimés par cette action.

Le lecteur et Chapitre suivant ne sélectionnent que des documents présents localement. Cette version n’ajoute pas de détection de nouveaux chapitres sur les sites.

## AniList

Les requêtes demandent désormais `status` et `chapters`. La valeur `FINISHED` est affichée comme « Publication terminée », distinctement de la progression de lecture. Les autres statuts de publication apparaissent dans la fiche. Une association existante est rafraîchie par identifiant AniList pour préserver la couverture choisie ; les échecs conservent le cache.

Le champ `chapters` est le total d’un manga terminé, pas un numéro fiable du dernier chapitre publié pour un manga en cours. Aucun statut « À jour » n’est calculé. Référence : [Media](https://docs.anilist.co/reference/object/media), [MediaStatus](https://docs.anilist.co/reference/enum/mediastatus).

La vérification HTTP depuis le Mac pendant cette livraison a reçu un 403 d’AniList. Le contrat, la recherche et la mise à jour par identifiant sont testés avec des réponses contrôlées ; aucun succès réseau en direct n’est revendiqué pour cette livraison. Métadonnées et couvertures restent facultatives, la lecture locale fonctionne sans elles.

## Stockage et validation

Réglages mesure les fichiers de bibliothèque, les couvertures/métadonnées et le cache propre à MangaFlow. Ces chiffres ne représentent pas toute la taille de l’application et excluent ses modèles embarqués. Vider le cache retire les couvertures retéléchargeables et le cache de rendu, sans effacer l’historique ni les associations AniList.

Tests unitaires : `xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow -destination 'platform=iOS Simulator,name=MangaFlow-Test' -only-testing:MangaFlowTests test`.

Les tests visuels utilisent `Scripts/prepare_redesign_fixture.py <simulator UUID>` sur un simulateur jetable, puis `ThemeWorkflowTests`. Le test destructif refuse de s’exécuter hors du simulateur marqué par cette fixture. `Scripts/prepare_reader_zoom_fixture.py` prépare les pages synthétiques du contrôle de régression des gestes. Les CBZ privés ne sont pas ajoutés au dépôt.

Validation de livraison : 79 tests unitaires, dont trois revues privées opt-in ignorées ; contrôles UI des apparences, persistance, connexion dans Réglages, suppression locale et historique après relancement sur iPhone ; contrôles de navigation en portrait/paysage sur iPhone et iPad ; zoom case/bulle/texte et toucher à deux doigts sur les deux appareils. Le contrôle iPhone fait défiler le dernier manga et le dernier chapitre au-dessus de la barre native, puis ouvre la fiche. Les captures de contrôle sont dans `Artifacts/RedesignQA` et `Artifacts/RedesignQA-iPad` (ignorées par Git).
