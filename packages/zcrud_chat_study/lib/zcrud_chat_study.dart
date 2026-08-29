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
/// | `routing/` | adaptateurs **par route** des six ports de génération d'étude, et leur câblage d'ensemble |
///
/// ## Le transport « par route »
///
/// Deux modes de transport coexistent chez les hôtes : un endpoint unique à
/// corps riche, et **une route par intention de génération** — mode qui porte
/// la gouvernance (une route et ses accès associés à un palier d'abonnement)
/// et permet de déclarer par tâche le modèle par défaut. Les ports d'étude
/// restent NEUTRES : une route y est une **donnée**, jamais une URL. Les
/// adaptateurs de `routing/` sont la couche qui lit cette route dans un
/// catalogue, la soumet à une gouvernance, puis délègue au port branché sur
/// elle. Ils vivent ici parce que ce paquet est le seul à connaître les deux
/// côtés — le domaine d'étude n'a aucune arête vers le domaine du chat.
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

export 'src/domain/routing/z_chat_routed_ai_explanation_port.dart';
export 'src/domain/routing/z_chat_routed_ai_explanation_stream_port.dart';
export 'src/domain/routing/z_chat_routed_flashcard_generation_port.dart';
export 'src/domain/routing/z_chat_routed_mindmap_generation_port.dart';
export 'src/domain/routing/z_chat_routed_note_summary_port.dart';
export 'src/domain/routing/z_chat_routed_podcast_generation_port.dart';
export 'src/domain/routing/z_routed_study_dispatch.dart';
export 'src/domain/routing/z_routed_study_ports.dart';
export 'src/domain/z_chat_flashcard_generator.dart';
export 'src/domain/z_chat_flashcard_mapper.dart';
export 'src/domain/z_chat_study_launch.dart';
export 'src/domain/z_chat_study_pool.dart';
