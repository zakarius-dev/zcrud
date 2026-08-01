/// Barrel d'API publique de `zcrud_chat_study` — le **pont** conversation → SRS.
///
/// ## Ce paquet est délibérément MINCE
///
/// Le lot CHAT-8 était planifié comme un portage complet du parcours d'étude.
/// Mesure faite sur disque **avant** d'écrire une ligne : `zcrud_flashcard` et
/// `zcrud_session` portent DÉJÀ l'entité de carte, l'ordonnanceur SM-2, le
/// moteur de session, la file, les modes et le runtime d'examen blanc ;
/// `zcrud_study` porte DÉJÀ le port de génération IA et ses normaliseurs ;
/// `zcrud_study_kernel` porte DÉJÀ le sélecteur de session. Il ne manquait que
/// **le pont** — un mapper et un pool. C'est tout ce qu'on trouve ici.
///
/// | Fichier | Rôle |
/// |---|---|
/// | `z_chat_flashcard_mapper.dart` | conversation/message → `ZFlashcardGenerationRequest` + provenance `ZConversationSource` |
/// | `z_chat_flashcard_generator.dart` | **câblage** du `ZFlashcardGenerationPort` existant + estampillage défensif |
/// | `z_chat_study_pool.dart` | pool de session : cartes du dossier ∪ cartes de la conversation, **dédoublonnées** |
/// | `z_chat_study_launch.dart` | les 3 modes offerts par « Commencer à apprendre » + ce qui n'est PAS porté |
///
/// ## Pourquoi un paquet séparé (AD-1)
///
/// `zcrud_chat`/`zcrud_chat_kernel` ne doivent **jamais** dépendre de
/// `zcrud_flashcard` : DODLP et DLCFTI utilisent le chat sans le domaine
/// d'étude et en porteraient le poids sans usage. Symétriquement,
/// `zcrud_flashcard` ne doit pas connaître le chat. Le pont vit donc dans son
/// propre satellite, qui dépend des deux et dont **rien ne dépend**.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/domain/z_chat_flashcard_generator.dart';
export 'src/domain/z_chat_flashcard_mapper.dart';
export 'src/domain/z_chat_study_launch.dart';
export 'src/domain/z_chat_study_pool.dart';
