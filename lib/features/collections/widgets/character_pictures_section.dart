import 'package:core/models/character_image.dart';
import 'package:core/models/image_type.dart';
import 'package:core/utils/stable_id.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/url_launch.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/section_header.dart';
import 'dialogs/add_character_image_dialog.dart';

/// The pictures the user attached to a character — stills, wallpapers, a
/// "best look" shot from anywhere online.
///
/// The section only reports changes; the page persists them.
class CharacterPicturesSection extends StatelessWidget {
  const CharacterPicturesSection({
    required this.images,
    required this.onChanged,
    this.isEditable = true,
    super.key,
  });

  /// The pictures currently attached.
  final List<CharacterImage> images;

  /// Called with the new list whenever a picture is added or removed.
  final ValueChanged<List<CharacterImage>> onChanged;

  /// False on a read-only item, where the pictures can only be viewed.
  final bool isEditable;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: l.characterPictures),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              l.characterPictures,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: images.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final CharacterImage image = images[index];
                return _PictureTile(
                  image: image,
                  isEditable: isEditable,
                  onOpen: () => launchExternalUrl(image.url),
                  onRemove: () => onChanged(
                    images.where((CharacterImage i) => i != image).toList(),
                  ),
                );
              },
            ),
          ),
        if (isEditable)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(l.characterAddPicture),
            ),
          ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final CharacterImage? added = await AddCharacterImageDialog.show(context);
    if (added == null || !context.mounted) return;
    onChanged(<CharacterImage>[...images, added]);
  }
}

class _PictureTile extends StatelessWidget {
  const _PictureTile({
    required this.image,
    required this.isEditable,
    required this.onOpen,
    required this.onRemove,
  });

  final CharacterImage image;
  final bool isEditable;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              GestureDetector(
                onTap: onOpen,
                child: CachedImage(
                  imageType: ImageType.characterCover,
                  // The link is the identity, so the same URL reuses the file.
                  imageId: 'user_${fnv1a53(image.url)}',
                  remoteUrl: image.url,
                  width: 104,
                  height: 96,
                  fit: BoxFit.cover,
                  memCacheWidth: 208,
                  errorWidget: Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (isEditable)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: l.characterPictureRemove,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.scrim.withAlpha(140),
                      foregroundColor: AppColors.onOverlay,
                      minimumSize: const Size(24, 24),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
            ],
          ),
          if (image.caption != null)
            Text(
              image.caption!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
