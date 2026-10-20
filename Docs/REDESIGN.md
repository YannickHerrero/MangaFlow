# Interface unifiée — build 16

L’interface reprend la maquette « Application de lecture – Bibliothèque » : fond blanc cassé/noir, police système, listes compactes, couvertures facultatives, boutons ronds et réglages en feuille. Les quatre thèmes précédents et leurs polices sont supprimés. Le choix système/clair/sombre reste mémorisé. La navigation conserve deux onglets Bibliothèque et Explorer. Après comparaison avec les PNG, une barre personnalisée large utilise le véritable matériau Liquid Glass d’Apple ; le TabView natif conserve les routes en arrière-plan. Il n’y a plus de page Activité.

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


## Rapprochement avec les sept maquettes PNG

Explorer reprend la recherche fine, le sélecteur Mangas / Sources avec compteurs, les favoris en lignes compactes, les étoiles dorées et les pastilles. Les favoris de sources gardent leur format persistant existant et leur isolation par serveur. Un conteneur stable autour du bloc Favoris permet de refléter un ajout immédiatement, sans attendre un relancement. Les filtres de langue et de catalogue complet sont accessibles depuis l’en-tête ; import CBZ et connexion restent dans la feuille de réglages.

Le catalogue dispose d’une rangée d’actions, d’un grand titre unique, de lignes transparentes et des compteurs de chapitres réellement présents sur l’appareil. La synchronisation et son diagnostic sont dans le menu ; la recherche est toujours explicitement locale. Le tri A–Z est appliqué par le serveur avant la pagination (`sort=title`), avec comparaison naturelle des titres et départage stable par identifiant. Populaires et Récents sont désactivés : les connecteurs exposés ne fournissent pas ces classements. Aucun auteur ni volume n’est inventé quand la source ne les fournit pas.

La fiche distante comporte le badge Suivi, le résumé Dans la bibliothèque, une progression et une action d’ajout en lot. Les chapitres sont des lignes avec bouton circulaire : lire s’ils sont locaux, télécharger ou importer sinon, avec progression, annulation et erreur dans la même ligne. Le tri et le filtre des chapitres lus sont dans le menu. La barre principale disparaît dans les sous-pages puis revient au retour ; les racines réservent un vrai espace à cette barre pour que la fin des listes reste accessible. La bibliothèque reprend les graisses des compteurs, les réglages ont leurs chevrons et des unités françaises ; les feuilles peuvent s’ouvrir à une hauteur de 720 points ou être agrandies.

### Ajout en lot

La sélection porte sur les chapitres absents localement, en excluant les demandes déjà actives. Une confirmation annonce le nombre avant de programmer le lot. Les demandes non encore envoyées sont conservées dans `AutomaticImportQueue`, avec une clé HTTP d’idempotence stable par demande. Les envois sont séquentiels ; le Mac conserve sa propre concurrence et sa file persistante. Une interruption du téléphone garde les envois restants pour le retour au premier plan. Les tâches déjà acceptées continuent sur le Mac.

Une erreur conserve le lot et le met en attente d’une nouvelle tentative explicite. « Annuler les envois restants » retire uniquement les demandes pas encore acceptées ; les tâches acceptées gardent leur bouton d’annulation individuel. L’import automatique existant est réutilisé, sans ouverture forcée du lecteur. Les identités de déduplication et les compteurs reposent sur serveur/source/manga/chapitre, jamais sur le titre d’affichage.

Validation : suite Swift de 83 tests (trois revues privées opt-in ignorées), tests de persistance du lot, échec HTTP et reprise avec les mêmes clés, absence de doublons après changement de titre, isolation serveur/source et fichiers supprimés. Neuf tests serveur, dont tri avant pagination. Navigation réelle LELScan / Blue Lock vérifiée en clair et sombre sans lancer le téléchargement massif des centaines de chapitres proposés. Le lot est validé avec des réponses HTTP contrôlées ; le transfert et la conversion continuent d’utiliser le pipeline déjà testé. Les captures restent dans Artifacts et ne sont pas publiées avec les pages privées.

Contrôles UI complémentaires : favoris de source visibles dès l’ajout et conservés après relancement ; limites de défilement en portrait/paysage sur iPhone et iPad ; tri et filtre de la fiche locale via sa feuille de réglages ; régression du zoom case/bulle/texte et du toucher à deux doigts sur iPad. Le service Mac a été relancé et son accès privé reste opérationnel. Aucun build TestFlight supplémentaire n’a été publié pour cette itération.
