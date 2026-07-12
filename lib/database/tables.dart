/// Raw SQL schema for OmniCore's offline-first local database.
///
/// We use Drift's *runtime* API (no build_runner code generation required) so
/// the project compiles immediately on `flutter build apk`. These statements
/// create the SQLite tables; typed Dart accessors live in [OmniDatabase].
class SchemaSql {
  SchemaSql._();

  static const List<String> createAll = [
    _fileNodes,
    _trashItems,
    _galleryItems,
    _mailMessages,
    _mailAccounts,
    _userPreferences,
    _beamTransfers,
  ];

  static const String _fileNodes = '''
CREATE TABLE IF NOT EXISTS file_nodes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  path TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  size_bytes INTEGER NOT NULL DEFAULT 0,
  parent_id TEXT,
  modified_at INTEGER NOT NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  tags TEXT NOT NULL DEFAULT '',
  indexed_at INTEGER NOT NULL
)''';

  static const String _trashItems = '''
CREATE TABLE IF NOT EXISTS trash_items (
  id TEXT PRIMARY KEY,
  file_id TEXT NOT NULL,
  name TEXT NOT NULL,
  path TEXT NOT NULL,
  kind TEXT NOT NULL,
  size_bytes INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER NOT NULL,
  restored_path TEXT
)''';

  static const String _galleryItems = '''
CREATE TABLE IF NOT EXISTS gallery_items (
  id TEXT PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  captured_at INTEGER NOT NULL,
  width INTEGER NOT NULL DEFAULT 0,
  height INTEGER NOT NULL DEFAULT 0,
  tags TEXT NOT NULL DEFAULT '',
  ai_state TEXT NOT NULL DEFAULT 'pending',
  rotation REAL NOT NULL DEFAULT 0.0,
  pinned INTEGER NOT NULL DEFAULT 1
)''';

  static const String _mailMessages = '''
CREATE TABLE IF NOT EXISTS mail_messages (
  id TEXT PRIMARY KEY,
  from_addr TEXT NOT NULL,
  from_name TEXT NOT NULL,
  subject TEXT NOT NULL,
  preview TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  received_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'inbox',
  mail_rate INTEGER NOT NULL DEFAULT 0,
  is_starred INTEGER NOT NULL DEFAULT 0,
  has_attachment INTEGER NOT NULL DEFAULT 0,
  attachments TEXT NOT NULL DEFAULT ''
)''';

  static const String _mailAccounts = '''
CREATE TABLE IF NOT EXISTS mail_accounts (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL,
  imap_host TEXT NOT NULL,
  imap_port INTEGER NOT NULL DEFAULT 993,
  smtp_host TEXT NOT NULL,
  smtp_port INTEGER NOT NULL DEFAULT 587,
  username TEXT NOT NULL,
  password_enc TEXT NOT NULL,
  use_tls INTEGER NOT NULL DEFAULT 1
)''';

  static const String _userPreferences = '''
CREATE TABLE IF NOT EXISTS user_preferences (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''';

  static const String _beamTransfers = '''
CREATE TABLE IF NOT EXISTS beam_transfers (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  device_name TEXT NOT NULL,
  file_name TEXT NOT NULL,
  size_bytes INTEGER NOT NULL DEFAULT 0,
  sent_bytes INTEGER NOT NULL DEFAULT 0,
  started_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  transport TEXT NOT NULL DEFAULT 'webrtc'
)''';

  /// Useful indexes for common lookups.
  static const List<String> indexes = [
    'CREATE INDEX IF NOT EXISTS idx_file_parent ON file_nodes(parent_id)',
    'CREATE INDEX IF NOT EXISTS idx_file_kind ON file_nodes(kind)',
    'CREATE INDEX IF NOT EXISTS idx_trash_deleted ON trash_items(deleted_at)',
    'CREATE INDEX IF NOT EXISTS idx_mail_status ON mail_messages(status)',
    'CREATE INDEX IF NOT EXISTS idx_mail_received ON mail_messages(received_at)',
    'CREATE INDEX IF NOT EXISTS idx_gallery_captured ON gallery_items(captured_at)',
  ];
}
