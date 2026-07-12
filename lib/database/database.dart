import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/file_node.dart';
import '../models/gallery_item.dart';
import '../models/mail_message.dart';
import '../models/nearby_device.dart';
import 'tables.dart';

/// OmniCore's offline-first local database (Drift + SQLite).
///
/// Uses Drift's **runtime** API — no `build_runner` code generation is
/// required. The schema is created from [SchemaSql] in [migration] and queries
/// run via `customSelect` / `customInsert` / `customUpdate`. All public methods
/// return strongly-typed model objects so callers never touch SQL.
class OmniDatabase extends GeneratedDatabase {
  OmniDatabase(super.e);

  /// Opens (or creates) the on-disk SQLite database in the app-support dir.
  factory OmniDatabase.open() {
    return OmniDatabase(_openConnection());
  }

  /// In-memory database, useful for tests and ephemeral sessions.
  factory OmniDatabase.memory() {
    return OmniDatabase(NativeDatabase.memory());
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'omnicore.sqlite'));
      return NativeDatabase.createInBackground(
        file,
        logStatements: false,
        // Guarantee the schema exists at the SQLite level on every connection,
        // independent of Drift's migration hook. Idempotent via IF NOT EXISTS.
        setup: (rawDb) {
          for (final stmt in SchemaSql.createAll) {
            rawDb.execute(stmt);
          }
          for (final idx in SchemaSql.indexes) {
            rawDb.execute(idx);
          }
          final cutoff = DateTime.now().millisecondsSinceEpoch -
              TrashItem.retention.inMilliseconds;
          rawDb.execute(
            'DELETE FROM trash_items WHERE deleted_at < ?',
            [cutoff],
          );
        },
      );
    });
  }

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await _ensureSchema();
        },
        beforeOpen: (details) async {
          await _ensureSchema();
          await _purgeExpiredTrash();
        },
      );

  Future<void> _ensureSchema() async {
    for (final stmt in SchemaSql.createAll) {
      await customStatement(stmt);
    }
    for (final idx in SchemaSql.indexes) {
      await customStatement(idx);
    }
  }

  // ---------------------------------------------------------------------------
  // File index
  // ---------------------------------------------------------------------------

  Future<List<FileNode>> listFiles({String? parentId}) async {
    final result = parentId == null
        ? await customSelect(
            "SELECT * FROM file_nodes WHERE parent_id IS NULL OR parent_id = '' "
            "ORDER BY (kind='folder') DESC, name COLLATE NOCASE ASC",
          ).get()
        : await customSelect(
            'SELECT * FROM file_nodes WHERE parent_id = ? '
            "ORDER BY (kind='folder') DESC, name COLLATE NOCASE ASC",
            variables: [Variable.withString(parentId)],
          ).get();
    return result.map(_rowToFileNode).toList();
  }

  Future<FileNode?> getFile(String id) async {
    final result = await customSelect(
      'SELECT * FROM file_nodes WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();
    return result.isEmpty ? null : _rowToFileNode(result.first);
  }

  Future<void> upsertFile(FileNode node) async {
    await customInsert(
      'INSERT INTO file_nodes (id, name, path, kind, size_bytes, parent_id, '
      'modified_at, is_favorite, tags, indexed_at) VALUES (?, ?, ?, ?, ?, ?, '
      '?, ?, ?, ?) ON CONFLICT(path) DO UPDATE SET name=excluded.name, '
      'kind=excluded.kind, size_bytes=excluded.size_bytes, '
      'modified_at=excluded.modified_at, is_favorite=excluded.is_favorite, '
      'tags=excluded.tags',
      variables: [
        Variable.withString(node.id),
        Variable.withString(node.name),
        Variable.withString(node.path),
        Variable.withString(node.kind.name),
        Variable.withInt(node.sizeBytes),
        Variable.withString(node.parentId ?? ''),
        Variable.withInt(node.modifiedAt.millisecondsSinceEpoch),
        Variable.withBool(node.isFavorite),
        Variable.withString(node.tags.join(',')),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  Future<void> deleteFile(String id) async {
    await customUpdate(
      'DELETE FROM file_nodes WHERE id = ?',
      variables: [Variable.withString(id)],
    );
  }

  Future<void> setFavorite(String id, bool fav) async {
    await customUpdate(
      'UPDATE file_nodes SET is_favorite = ? WHERE id = ?',
      variables: [Variable.withBool(fav), Variable.withString(id)],
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Trash
  // ---------------------------------------------------------------------------

  Future<List<TrashItem>> listTrash() async {
    final result = await customSelect(
      'SELECT * FROM trash_items ORDER BY deleted_at DESC',
    ).get();
    return result.map(_rowToTrashItem).toList();
  }

  Future<void> moveToTrash(FileNode node) async {
    await customInsert(
      'INSERT INTO trash_items (id, file_id, name, path, kind, size_bytes, '
      'deleted_at, restored_path) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(node.id),
        Variable.withString(node.id),
        Variable.withString(node.name),
        Variable.withString(node.path),
        Variable.withString(node.kind.name),
        Variable.withInt(node.sizeBytes),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(node.path),
      ],
    );
    await deleteFile(node.id);
  }

  Future<void> restoreTrash(String trashId) async {
    final result = await customSelect(
      'SELECT * FROM trash_items WHERE id = ?',
      variables: [Variable.withString(trashId)],
    ).get();
    if (result.isEmpty) return;
    final t = _rowToTrashItem(result.first);
    await customUpdate(
      'DELETE FROM trash_items WHERE id = ?',
      variables: [Variable.withString(trashId)],
    );
    await upsertFile(FileNode(
      id: t.fileId,
      name: t.name,
      path: t.path,
      kind: t.kind,
      sizeBytes: t.sizeBytes,
      parentId: null,
      modifiedAt: DateTime.now(),
    ));
  }

  Future<void> purgeTrash(String trashId) async {
    await customUpdate(
      'DELETE FROM trash_items WHERE id = ?',
      variables: [Variable.withString(trashId)],
    );
  }

  Future<void> _purgeExpiredTrash() async {
    final cutoff = DateTime.now().millisecondsSinceEpoch -
        TrashItem.retention.inMilliseconds;
    await customUpdate(
      'DELETE FROM trash_items WHERE deleted_at < ?',
      variables: [Variable.withInt(cutoff)],
    );
  }

  // ---------------------------------------------------------------------------
  // Gallery
  // ---------------------------------------------------------------------------

  Future<List<GalleryItem>> listGallery() async {
    final result = await customSelect(
      'SELECT * FROM gallery_items ORDER BY captured_at DESC',
    ).get();
    return result.map(_rowToGalleryItem).toList();
  }

  Future<void> upsertGallery(GalleryItem item) async {
    await customInsert(
      'INSERT INTO gallery_items (id, path, captured_at, width, height, tags, '
      'ai_state, rotation, pinned) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(path) DO UPDATE SET tags=excluded.tags, '
      'ai_state=excluded.ai_state, rotation=excluded.rotation, '
      'pinned=excluded.pinned',
      variables: [
        Variable.withString(item.id),
        Variable.withString(item.path),
        Variable.withInt(item.capturedAt.millisecondsSinceEpoch),
        Variable.withInt(item.width),
        Variable.withInt(item.height),
        Variable.withString(item.tags.join(',')),
        Variable.withString(item.aiState.name),
        Variable.withReal(item.rotation),
        Variable.withBool(item.pinned),
      ],
    );
  }

  Future<void> deleteGallery(String id) async {
    await customUpdate(
      'DELETE FROM gallery_items WHERE id = ?',
      variables: [Variable.withString(id)],
    );
  }

  // ---------------------------------------------------------------------------
  // Mail
  // ---------------------------------------------------------------------------

  Future<List<MailMessage>> listMail(MailStatus status) async {
    final result = await customSelect(
      'SELECT * FROM mail_messages WHERE status = ? ORDER BY received_at DESC',
      variables: [Variable.withString(status.name)],
    ).get();
    return result.map(_rowToMail).toList();
  }

  Future<List<MailMessage>> listOutbox() async {
    final result = await customSelect(
      "SELECT * FROM mail_messages WHERE status = 'outbox' ORDER BY received_at ASC",
    ).get();
    return result.map(_rowToMail).toList();
  }

  Future<void> upsertMail(MailMessage m) async {
    await customInsert(
      'INSERT INTO mail_messages (id, from_addr, from_name, subject, preview, '
      'body, received_at, status, mail_rate, is_starred, has_attachment, '
      'attachments) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET status=excluded.status, '
      'mail_rate=excluded.mail_rate, is_starred=excluded.is_starred',
      variables: [
        Variable.withString(m.id),
        Variable.withString(m.from),
        Variable.withString(m.fromName),
        Variable.withString(m.subject),
        Variable.withString(m.preview),
        Variable.withString(m.body),
        Variable.withInt(m.receivedAt.millisecondsSinceEpoch),
        Variable.withString(m.status.name),
        Variable.withInt(m.mailRate),
        Variable.withBool(m.isStarred),
        Variable.withBool(m.hasAttachment),
        Variable.withString(m.attachments.join(',')),
      ],
    );
  }

  Future<void> deleteMail(String id) async {
    await customUpdate(
      'DELETE FROM mail_messages WHERE id = ?',
      variables: [Variable.withString(id)],
    );
  }

  Future<List<MailAccount>> listAccounts() async {
    final result = await customSelect('SELECT * FROM mail_accounts').get();
    return result.map(_rowToAccount).toList();
  }

  Future<void> upsertAccount(MailAccount a) async {
    await customInsert(
      'INSERT INTO mail_accounts (id, email, display_name, imap_host, '
      'imap_port, smtp_host, smtp_port, username, password_enc, use_tls) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
      'email=excluded.email, display_name=excluded.display_name, '
      'imap_host=excluded.imap_host, smtp_host=excluded.smtp_host, '
      'username=excluded.username, password_enc=excluded.password_enc, '
      'use_tls=excluded.use_tls',
      variables: [
        Variable.withString(a.id),
        Variable.withString(a.email),
        Variable.withString(a.displayName),
        Variable.withString(a.imapHost),
        Variable.withInt(a.imapPort),
        Variable.withString(a.smtpHost),
        Variable.withInt(a.smtpPort),
        Variable.withString(a.username),
        Variable.withString(a.passwordEnc),
        Variable.withBool(a.useTls),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preferences (synced to Supabase when authenticated)
  // ---------------------------------------------------------------------------

  Future<String?> getPref(String key) async {
    final result = await customSelect(
      'SELECT value FROM user_preferences WHERE key = ?',
      variables: [Variable.withString(key)],
    ).get();
    return result.isEmpty ? null : result.first.read<String>('value');
  }

  Future<void> setPref(String key, String value) async {
    await customInsert(
      'INSERT INTO user_preferences (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      variables: [Variable.withString(key), Variable.withString(value)],
    );
  }

  Future<Map<String, String>> allPrefs() async {
    final result =
        await customSelect('SELECT key, value FROM user_preferences').get();
    return {
      for (final r in result)
        r.read<String>('key'): r.read<String>('value'),
    };
  }

  // ---------------------------------------------------------------------------
  // Beam transfers
  // ---------------------------------------------------------------------------

  Future<List<BeamTransfer>> listBeamHistory() async {
    final result = await customSelect(
      'SELECT * FROM beam_transfers ORDER BY started_at DESC LIMIT 200',
    ).get();
    return result.map(_rowToBeam).toList();
  }

  Future<void> upsertBeam(BeamTransfer t) async {
    await customInsert(
      'INSERT INTO beam_transfers (id, device_id, device_name, file_name, '
      'size_bytes, sent_bytes, started_at, status, transport) VALUES '
      '(?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
      'sent_bytes=excluded.sent_bytes, status=excluded.status',
      variables: [
        Variable.withString(t.id),
        Variable.withString(t.deviceId),
        Variable.withString(t.deviceName),
        Variable.withString(t.fileName),
        Variable.withInt(t.sizeBytes),
        Variable.withInt(t.sentBytes),
        Variable.withInt(t.startedAt.millisecondsSinceEpoch),
        Variable.withString(t.status.name),
        Variable.withString(t.transport.name),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Row mappers
  // ---------------------------------------------------------------------------

  FileNode _rowToFileNode(QueryRow r) {
    final parentIdRaw = r.read<String>('parent_id');
    return FileNode(
      id: r.read<String>('id'),
      name: r.read<String>('name'),
      path: r.read<String>('path'),
      kind: _kind(r.read<String>('kind')),
      sizeBytes: r.read<int>('size_bytes'),
      parentId: parentIdRaw.isEmpty ? null : parentIdRaw,
      modifiedAt:
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('modified_at')),
      isFavorite: r.read<int>('is_favorite') == 1,
      tags: _split(r.read<String>('tags')),
    );
  }

  TrashItem _rowToTrashItem(QueryRow r) {
    return TrashItem(
      id: r.read<String>('id'),
      fileId: r.read<String>('file_id'),
      name: r.read<String>('name'),
      path: r.read<String>('path'),
      kind: _kind(r.read<String>('kind')),
      sizeBytes: r.read<int>('size_bytes'),
      deletedAt:
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('deleted_at')),
      restoredPath: r.readNullable<String>('restored_path'),
    );
  }

  GalleryItem _rowToGalleryItem(QueryRow r) {
    return GalleryItem(
      id: r.read<String>('id'),
      path: r.read<String>('path'),
      capturedAt:
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('captured_at')),
      width: r.read<int>('width'),
      height: r.read<int>('height'),
      tags: _split(r.read<String>('tags')),
      aiState: AiTagState.values.byName(r.read<String>('ai_state')),
      rotation: r.read<double>('rotation'),
      pinned: r.read<int>('pinned') == 1,
    );
  }

  MailMessage _rowToMail(QueryRow r) {
    return MailMessage(
      id: r.read<String>('id'),
      from: r.read<String>('from_addr'),
      fromName: r.read<String>('from_name'),
      subject: r.read<String>('subject'),
      preview: r.read<String>('preview'),
      body: r.read<String>('body'),
      receivedAt:
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('received_at')),
      status: MailStatus.values.byName(r.read<String>('status')),
      mailRate: r.read<int>('mail_rate'),
      isStarred: r.read<int>('is_starred') == 1,
      hasAttachment: r.read<int>('has_attachment') == 1,
      attachments: _split(r.read<String>('attachments')),
    );
  }

  MailAccount _rowToAccount(QueryRow r) {
    return MailAccount(
      id: r.read<String>('id'),
      email: r.read<String>('email'),
      displayName: r.read<String>('display_name'),
      imapHost: r.read<String>('imap_host'),
      imapPort: r.read<int>('imap_port'),
      smtpHost: r.read<String>('smtp_host'),
      smtpPort: r.read<int>('smtp_port'),
      username: r.read<String>('username'),
      passwordEnc: r.read<String>('password_enc'),
      useTls: r.read<int>('use_tls') == 1,
    );
  }

  BeamTransfer _rowToBeam(QueryRow r) {
    return BeamTransfer(
      id: r.read<String>('id'),
      deviceId: r.read<String>('device_id'),
      deviceName: r.read<String>('device_name'),
      fileName: r.read<String>('file_name'),
      sizeBytes: r.read<int>('size_bytes'),
      sentBytes: r.read<int>('sent_bytes'),
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('started_at')),
      status: BeamTransferStatus.values.byName(r.read<String>('status')),
      transport: BeamTransport.values.byName(r.read<String>('transport')),
    );
  }

  FileNodeKind _kind(String s) {
    return FileNodeKind.values.firstWhere(
      (k) => k.name == s,
      orElse: () => FileNodeKind.other,
    );
  }

  List<String> _split(String s) {
    if (s.isEmpty) return const [];
    return s.split(',').where((e) => e.isNotEmpty).toList();
  }
}
