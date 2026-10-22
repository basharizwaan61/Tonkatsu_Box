import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/url_launch.dart';
import '../../../shared/widgets/section_header.dart';

/// The works a character shows up in, as tappable rows.
///
/// The source gives a link for some of them (Jikan's MyAnimeList pages) and
/// none for others (Disney lists titles only), so a row without a link is
/// plain text.
class CharacterAppearsInSection extends StatelessWidget {
  const CharacterAppearsInSection({
    required this.appearsIn,
    super.key,
  });

  /// Work title -> link, empty when the source gave none.
  final Map<String, String> appearsIn;

  @override
  Widget build(BuildContext context) {
    if (appearsIn.isEmpty) return const SizedBox.shrink();
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: l.characterAppearsIn),
        for (final MapEntry<String, String> entry in appearsIn.entries)
          _AppearsInRow(title: entry.key, url: entry.value),
      ],
    );
  }
}

class _AppearsInRow extends StatelessWidget {
  const _AppearsInRow({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final bool linked = url.isNotEmpty;
    return InkWell(
      onTap: linked ? () => launchExternalUrl(url) : null,
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
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: linked ? AppColors.brand : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (linked)
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
