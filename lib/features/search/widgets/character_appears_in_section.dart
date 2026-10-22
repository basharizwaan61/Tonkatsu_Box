import 'package:core/models/character_appearance.dart';
import 'package:core/models/collected_item_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/url_launch.dart';
import '../../../shared/widgets/section_header.dart';
import '../../collections/providers/collections_provider.dart';
import '../../collections/screens/item_detail_screen.dart';

/// The works a character shows up in.
///
/// A row opens the work in the user's own library when they already have it,
/// and the provider's page otherwise.
class CharacterAppearsInSection extends ConsumerWidget {
  const CharacterAppearsInSection({
    required this.appearsIn,
    super.key,
  });

  /// The works, keyed by title.
  final Map<String, CharacterAppearance> appearsIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (appearsIn.isEmpty) return const SizedBox.shrink();
    final S l = S.of(context);
    final Map<int, List<CollectedItemInfo>> owned = ref
        .watch(collectedAnimeIdsProvider)
        .valueOrNull ??
        const <int, List<CollectedItemInfo>>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: l.characterAppearsIn),
        for (final CharacterAppearance appearance in appearsIn.values)
          _AppearsInRow(
            appearance: appearance,
            owned: appearance.mediaId == null
                ? const <CollectedItemInfo>[]
                : (owned[appearance.mediaId] ?? const <CollectedItemInfo>[]),
            onOpenOwned: (CollectedItemInfo info) => _openOwnedItem(
              context,
              ref,
              info,
            ),
          ),
      ],
    );
  }

  Future<void> _openOwnedItem(
    BuildContext context,
    WidgetRef ref,
    CollectedItemInfo info,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ItemDetailScreen(
          collectionId: info.collectionId,
          itemId: info.recordId,
          isEditable: info.collectionId != null,
        ),
      ),
    );
  }
}

class _AppearsInRow extends StatelessWidget {
  const _AppearsInRow({
    required this.appearance,
    required this.owned,
    required this.onOpenOwned,
  });

  final CharacterAppearance appearance;

  /// The user's own copies of this work.
  final List<CollectedItemInfo> owned;

  final void Function(CollectedItemInfo info) onOpenOwned;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    final bool inLibrary = owned.isNotEmpty;
    final String? url = appearance.url;
    return InkWell(
      onTap: () {
        if (inLibrary) {
          onOpenOwned(owned.first);
          return;
        }
        if (url != null && url.isNotEmpty) launchExternalUrl(url);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.movie_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                appearance.title,
                style: AppTypography.bodySmall.copyWith(
                  color: inLibrary ? AppColors.brand : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (inLibrary) ...<Widget>[
              Icon(
                Icons.library_add_check_outlined,
                size: 15,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l.characterInLibrary,
                style: AppTypography.caption.copyWith(
                  color: AppColors.brand,
                ),
              ),
            ] else if (url != null && url.isNotEmpty)
              Icon(
                Icons.open_in_new,
                size: 14,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
