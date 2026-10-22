/// Allowlist of upstreams, shared so the browser's rewrite and the server's
/// refusal cannot drift. One host per constant; API hosts only.
enum ProxyTarget {
  anilist('graphql.anilist.co'),
  comicvine('comicvine.gamespot.com'),
  disney('api.disneyapi.dev'),
  /// Fandom serves every wiki from its own `*.fandom.com` subdomain
  /// (`marvel.fandom.com`) and the apex does not answer `api.php` at all.
  /// The host stands for the whole family, and the wiki travels in the path.
  fandom('fandom.com', family: true),
  fantlab('api.fantlab.ru'),
  googlebooks('www.googleapis.com'),
  hardcover('api.hardcover.app'),
  igdb('api.igdb.com'),
  jikan('api.jikan.moe'),
  kitsu('kitsu.io'),
  listenbrainz('api.listenbrainz.org'),
  mangabaka('api.mangabaka.org'),
  mangadex('api.mangadex.org'),
  musicbrainz('musicbrainz.org'),
  openlibrary('openlibrary.org'),
  podcastindex('api.podcastindex.org'),
  ra('retroachievements.org'),
  screenscraper('api.screenscraper.fr'),
  simkl('api.simkl.com'),
  steam('api.steampowered.com'),
  steamgriddb('www.steamgriddb.com'),
  superhero('superheroapi.com'),
  tmdb('api.themoviedb.org'),
  tvdb('api4.thetvdb.com'),
  tvmaze('api.tvmaze.com'),
  /// Wikidata holds the entity, Wikipedia the article about it — two hosts
  /// for one source, and the table keeps one host per constant.
  wikidata('www.wikidata.org'),
  wikipedia('en.wikipedia.org'),
  vndb('api.vndb.org');

  const ProxyTarget(this.host, {this.family = false});

  final String host;

  /// True when [host] is an apex that every member lives under — Fandom's
  /// wikis are all `*.fandom.com`.
  final bool family;

  /// The path segment. Reusing [name] keeps the two from ever disagreeing.
  String get slug => name;
}

/// Where `/proxy` lives, so both ends spell the prefix once.
const String kProxyPathPrefix = '/proxy';

final Map<String, ProxyTarget> _byHost = <String, ProxyTarget>{
  for (final ProxyTarget t in ProxyTarget.values) t.host: t,
};

final Map<String, ProxyTarget> _bySlug = <String, ProxyTarget>{
  for (final ProxyTarget t in ProxyTarget.values) t.slug: t,
};

/// Null for anything off the allowlist — a Kodi box on the user's own LAN, say,
/// which the browser has no business reaching through our server.
ProxyTarget? proxyTargetForHost(String host) {
  final String key = host.toLowerCase();
  final ProxyTarget? exact = _byHost[key];
  if (exact != null) return exact;
  for (final ProxyTarget t in ProxyTarget.values) {
    if (t.family && key.endsWith('.$t.host')) return t;
  }
  return null;
}

/// The member a family host names — `marvel.fandom.com` reads `marvel`.
/// Null for an exact host or a host off the allowlist.
String? familyLabelForHost(String host) {
  final String key = host.toLowerCase();
  for (final ProxyTarget t in ProxyTarget.values) {
    if (t.family && key.endsWith('.$t.host')) {
      return key.substring(0, key.length - t.host.length - 1);
    }
  }
  return null;
}

ProxyTarget? proxyTargetForSlug(String slug) => _bySlug[slug];
