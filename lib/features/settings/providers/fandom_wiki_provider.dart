import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fandom serves every wiki from its own domain and offers no cross-wiki
/// character search, so the character search reads the one wiki the user
/// picked.
class FandomWikiNotifier extends AsyncNotifier<String> {
  /// The wiki used until the user picks another one.
  static const String defaultWiki = 'marvel';

  /// Prefs key. The value is the wiki slug (`marvel`), not a full domain.
  static const String prefsKey = 'fandom_wiki';

  @override
  Future<String> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return normalizeWiki(prefs.getString(prefsKey) ?? defaultWiki);
  }

  /// Stores [wiki] as the wiki the character search reads.
  Future<void> setWiki(String wiki) async {
    final String slug = normalizeWiki(wiki);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, slug);
    state = AsyncData<String>(slug);
  }

  /// `Marvel`, `marvel.fandom.com` and `https://marvel.fandom.com/wiki/X`
  /// all mean `marvel`.
  static String normalizeWiki(String wiki) {
    String slug = wiki.trim().toLowerCase();
    const String suffix = '.fandom.com';
    if (slug.endsWith(suffix)) {
      slug = slug.substring(0, slug.length - suffix.length);
    }
    final int slash = slug.indexOf('/');
    if (slash >= 0) slug = slug.substring(0, slash);
    return slug.isEmpty ? defaultWiki : slug;
  }
}

final AsyncNotifierProvider<FandomWikiNotifier, String> fandomWikiProvider =
    AsyncNotifierProvider<FandomWikiNotifier, String>(FandomWikiNotifier.new);

/// Wikis with a character catalogue worth searching by default.
const List<String> kPopularFandomWikis = <String>[
  'marvel',
  'dc',
  'disney',
  'harrypotter',
  'starwars',
  'transformers',
  'sherlock',
  'gameofthrones',
  'thewalkingdead',
  'naruto',
  'onepiece',
  'dragonball',
  'pokemon',
  'greekmythology',
  'dune',
  'tardis',
];
