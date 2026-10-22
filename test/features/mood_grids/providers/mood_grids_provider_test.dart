import 'package:core/database/dao/mood_grid_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediabox/features/mood_grids/providers/mood_grids_provider.dart';

void main() {
  group('aboutMeMediaboxCells', () {
    test('returns 5 cells matching the documented preset', () {
      final List<String?> labels = aboutMeMediaboxCells()
          .map((MoodGridCellSpec spec) => spec.label)
          .toList();

      expect(labels, <String>[
        'Favorite Game',
        'Favorite Movie',
        'Favorite TV Show',
        'Favorite Anime',
        'Favorite Manga',
      ]);
    });
  });

  test('kDefaultMoodGridTitle is "About Me: Mediabox"', () {
    expect(kDefaultMoodGridTitle, 'About Me: Mediabox');
  });
}
