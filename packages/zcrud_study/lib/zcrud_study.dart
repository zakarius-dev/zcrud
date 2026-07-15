/// Barrel d'API publique de `zcrud_study`.
///
/// Package de PRÉSENTATION de l'orchestration « study tools » (AD-25). ES-5.1
/// expose le SOCLE de décomposabilité : le descripteur de section paramétrique
/// [ZStudyToolsSectionSpec] et l'échafaudage de composition
/// [ZSectionedStudyLayout] (liste de sections INDÉPENDANTES, une frontière de
/// widget/Key par section). API publique = ce barrel ; implémentation sous
/// `lib/src/` (AD-1 : `zcrud_study → zcrud_core`/`zcrud_study_kernel`, jamais
/// l'inverse ; CORE OUT=0).
library;

export 'src/presentation/z_content_hub_sheet.dart';
export 'src/presentation/z_feature_availability.dart';
export 'src/presentation/z_item_actions_menu.dart';
export 'src/presentation/z_reorder_ids.dart';
export 'src/presentation/z_sectioned_study_layout.dart';
export 'src/presentation/z_study_tools_page.dart';
export 'src/presentation/z_study_tools_section_spec.dart';
