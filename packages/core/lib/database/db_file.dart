// Shared by the app (per-profile directory) and the selfhost server (volume),
// so the two never drift on which file they open.
//
// The name is inherited from the upstream project and is deliberately NOT
// rebranded: it is the file every existing installation already has open.
// Renaming it would orphan every user's library. Change it only together with
// a migration that renames the file in place.
const String kDatabaseFileName = 'tonkatsu_box.db';
