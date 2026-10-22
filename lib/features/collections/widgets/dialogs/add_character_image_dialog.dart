import 'package:core/models/character_image.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Asks for a picture the user wants to attach to a character.
///
/// Only a link is accepted: the picture lives on the internet, and the app
/// stores the link rather than a copy of the file.
class AddCharacterImageDialog extends StatefulWidget {
  const AddCharacterImageDialog({this.existing, super.key});

  /// The picture being edited; `null` when adding a new one.
  final CharacterImage? existing;

  /// Shows the dialog and returns the picture, or `null` when cancelled.
  static Future<CharacterImage?> show(
    BuildContext context, {
    CharacterImage? existing,
  }) {
    return showDialog<CharacterImage>(
      context: context,
      builder: (BuildContext _) =>
          AddCharacterImageDialog(existing: existing),
    );
  }

  @override
  State<AddCharacterImageDialog> createState() =>
      _AddCharacterImageDialogState();
}

class _AddCharacterImageDialogState extends State<AddCharacterImageDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.existing?.url ?? '');
    _captionController =
        TextEditingController(text: widget.existing?.caption ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final String url = _urlController.text.trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void _submit() {
    if (!_isValid) return;
    final String caption = _captionController.text.trim();
    Navigator.of(context).pop(
      CharacterImage(
        url: _urlController.text.trim(),
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l.characterAddPicture),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _urlController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.characterPictureUrl,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                decoration: InputDecoration(
                  labelText: l.characterPictureCaption,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: _isValid ? _submit : null,
          child: Text(l.save),
        ),
      ],
    );
  }
}
