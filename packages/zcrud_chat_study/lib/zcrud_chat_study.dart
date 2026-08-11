/// Barrel d'API publique de `zcrud_chat_study` — le pont entre une
/// conversation et le domaine d'étude par répétition espacée (SRS).
///
/// ## Un paquet délibérément mince
///
/// L'entité de carte, l'ordonnanceur de répétition, le moteur de session et
/// le port de génération IA existent déjà, respectivement dans
/// `zcrud_flashcard`, `zcrud_session`, `zcrud_study` et `zcrud_study_kernel`.
/// Ce paquet ne redéclare aucun de ces symboles : il câble une conversation
/// sur les contrats existants.
///
/// | Fichier | Rôle |
/// |---|---|
/// | `z_chat_flashcard_mapper.dart` | conversation/message → requête de génération + provenance conversationnelle |
/// | `z_chat_flashcard_generator.dart` | câblage du port de génération existant, avec estampillage défensif de la provenance |
/// | `z_chat_study_pool.dart` | pool de session : cartes du dossier union cartes de la conversation, dédoublonnées |
/// | `z_chat_study_launch.dart` | les modes offerts pour démarrer une session d'étude depuis une conversation |
///
/// ## Pourquoi un paquet séparé (invariant AD-1)
///
/// `zcrud_chat`/`zcrud_chat_kernel` ne dépendent jamais de `zcrud_flashcard` :
/// un consommateur qui utilise le chat sans le domaine d'étude n'en porte pas
/// le poids. Symétriquement, `zcrud_flashcard` ne connaît pas le chat. Le
/// pont vit donc dans son propre satellite, qui dépend des deux et dont rien
/// ne dépend.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/domain/z_chat_flashcard_generator.dart';
export 'src/domain/z_chat_flashcard_mapper.dart';
export 'src/domain/z_chat_study_launch.dart';
export 'src/domain/z_chat_study_pool.dart';
