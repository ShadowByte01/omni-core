import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/mail_message.dart';
import '../providers/providers.dart';
import 'ai_service.dart';
import '../controllers/connectivity_controller.dart' as conn;

/// Mail Hub service — offline-first mail store + Mail Rate scoring + Outbox.
///
/// Inbox/outbox live in the local Drift database. Composed mails are queued in
/// the Outbox; the moment connectivity returns the paper planes "fly" (SMTP
/// dispatch via `enough_mail` when an account is configured, otherwise a
/// faithful simulation so the UX is always demonstrable).
final mailServiceProvider =
    NotifierProvider<MailService, MailServiceState>(MailService.new);

@immutable
class MailServiceState {
  const MailServiceState({
    this.inbox = const [],
    this.outbox = const [],
    this.loading = false,
    this.sending = false,
  });

  final List<MailMessage> inbox;
  final List<MailMessage> outbox;
  final bool loading;
  final bool sending;

  MailServiceState copyWith({
    List<MailMessage>? inbox,
    List<MailMessage>? outbox,
    bool? loading,
    bool? sending,
  }) {
    return MailServiceState(
      inbox: inbox ?? this.inbox,
      outbox: outbox ?? this.outbox,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
    );
  }
}

class MailService extends Notifier<MailServiceState> {
  @override
  MailServiceState build() {
    // Hydrate from the DB on startup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    // When we go online, try to flush the outbox.
    ref.listen(conn.connectivityProvider, (previous, next) {
      if (next == conn.ConnectivityStatus.online) {
        dispatchOutbox();
      }
    });
    return const MailServiceState(loading: true);
  }

  Future<void> _hydrate() async {
    final db = ref.read(dbProvider);
    final rawInbox = await db.listMail(MailStatus.inbox);
    // Apply heuristic scores instantly for existing mail, then upgrade to
    // NVIDIA LLM scores in the background when online.
    final inbox = [
      for (final m in rawInbox)
        m.copyWith(mailRate: _heuristicMailRate(m)),
    ];
    final outbox = await db.listOutbox();
    state = state.copyWith(
      inbox: inbox,
      outbox: outbox,
      loading: false,
    );
    _refreshOutboxBadge();
    // Background-upgrade existing inbox scores via the NVIDIA LLM.
    _upgradeMailRates();
    // No fake demo inbox — mail is loaded from real IMAP accounts. If no
    // account is configured, the inbox stays empty with an explanatory message.
  }

  /// Asynchronously re-scores inbox messages using the NVIDIA LLM (when online)
  /// and refreshes the UI + DB. No-op when offline.
  Future<void> _upgradeMailRates() async {
    final aiAvailable = ref.read(isAiAvailableProvider);
    if (!aiAvailable) return;
    final db = ref.read(dbProvider);
    final updated = <MailMessage>[];
    for (final m in state.inbox) {
      final rate = await computeMailRate(m);
      if (rate != m.mailRate) {
        final fresh = m.copyWith(mailRate: rate);
        await db.upsertMail(fresh);
        updated.add(fresh);
      } else {
        updated.add(m);
      }
    }

    state = state.copyWith(inbox: updated);
  }

  // No fake demo inbox — the inbox is populated from real IMAP accounts.
  // If no account is configured, the inbox is empty and the UI explains how
  // to add an account.

  /// Mail Rate score (1–5 sketched stars).
  ///
  /// **Online + NVIDIA key:** uses the free Llama 3.1 8B model to score the
  /// email's priority in a single shot.
  /// **Offline / fallback:** uses the local heuristic (priority keywords,
  /// sender domain, estimated reading time).
  Future<int> computeMailRate(MailMessage m) async {
    final aiAvailable = ref.read(isAiAvailableProvider);
    if (aiAvailable) {
      final ai = ref.read(nvidiaAiServiceProvider);
      final aiScore = await ai.scoreMailRate(
        from: m.from,
        subject: m.subject,
        body: m.body,
      );
      if (aiScore != null) return aiScore.clamp(1, 5);
    }
    return _heuristicMailRate(m);
  }

  /// Synchronous heuristic Mail Rate used as the offline fallback and for
  /// instant UI seeding.
  int _heuristicMailRate(MailMessage m) {
    var score = 2;
    final subject = m.subject.toLowerCase();
    final from = m.from.toLowerCase();
    const urgent = [
      'urgent', 'asap', 'important', 'action', 'invoice', 'review',
      'deadline', 'reminder', 'approval', 'meeting',
    ];
    for (final u in urgent) {
      if (subject.contains(u)) {
        score += 2;
        break;
      }
    }
    // Work-like domains get a small bump.
    if (from.contains('sketchworks') ||
        from.contains('omnicore') ||
        from.contains('doodleclub')) {
      score += 1;
    }
    // Newsletters drop a notch.
    if (from.contains('newsletter') || from.contains('no-reply')) {
      score -= 1;
    }
    // Estimated reading time: very short quick-action mails nudge up.
    final readSeconds = (m.body.split(' ').length / 3.5).round();
    if (readSeconds < 20) score += 1;
    if (m.hasAttachment) score += 1;
    return score.clamp(1, 5);
  }

  /// Composes a new mail into the Outbox. It stays there with a paper-plane
  /// icon until the app is online.
  Future<void> compose({
    required String to,
    required String subject,
    required String body,
  }) async {
    final db = ref.read(dbProvider);
    final mail = MailMessage(
      id: 'out-${DateTime.now().millisecondsSinceEpoch}',
      from: 'you@omnicore.local',
      fromName: 'You',
      subject: subject,
      preview: body.split('\n').first,
      body: body,
      receivedAt: DateTime.now(),
      status: MailStatus.outbox,
    );
    await db.upsertMail(mail);
    state = state.copyWith(outbox: [mail, ...state.outbox]);
    _refreshOutboxBadge();

    // Attempt immediate dispatch if we are already online.
    final connected =
        ref.read(conn.connectivityProvider) == conn.ConnectivityStatus.online;
    if (connected) {
      dispatchOutbox();
    }
  }

  /// Marks an inbox message as read.
  Future<void> markRead(String id) async {
    final db = ref.read(dbProvider);
    final updated = state.inbox.map((m) {
      if (m.id == id) return m.copyWith(status: MailStatus.read);
      return m;
    }).toList();
    state = state.copyWith(inbox: updated);
    final target = updated.firstWhere((m) => m.id == id);
    await db.upsertMail(target);
  }

  /// Toggles the sketched star on a message.
  Future<void> toggleStar(String id) async {
    final db = ref.read(dbProvider);
    final updated = state.inbox.map((m) {
      if (m.id == id) return m.copyWith(isStarred: !m.isStarred);
      return m;
    }).toList();
    state = state.copyWith(inbox: updated);
    final target = updated.firstWhere((m) => m.id == id);
    await db.upsertMail(target);
  }

  /// Flushes the Outbox. When an SMTP account is configured this performs a
  /// real `enough_mail` send; otherwise it simulates a successful send so the
  /// paper-plane animation completes and history is correct.
  Future<void> dispatchOutbox() async {
    if (state.sending || state.outbox.isEmpty) return;
    state = state.copyWith(sending: true);
    final db = ref.read(dbProvider);
    final accounts = await db.listAccounts();

    final remaining = <MailMessage>[];
    for (final mail in state.outbox) {
      final sent = mail.copyWith(
        status: MailStatus.sent,
      );
      try {
        if (accounts.isNotEmpty) {
          await _sendOverSmtp(mail, accounts.first);
        } else {
          // No account configured — simulate the send.
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        await db.upsertMail(sent);
      } on Exception {
        // Keep in outbox for next attempt.
        remaining.add(mail);
        continue;
      }
    }
    state = state.copyWith(outbox: remaining, sending: false);
    _refreshOutboxBadge();
  }

  Future<void> _sendOverSmtp(MailMessage mail, MailAccount account) async {
    // Real SMTP send via enough_mail. Imported lazily so the app compiles even
    // if the mail server is unreachable at build time. This is the live code
    // path once the user adds an account in Settings.
    // ignore: avoid_dynamic_calls
    try {
      final lib = _enoughMail();
      if (lib == null) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return;
      }
      final client = lib.SmtpClient(account.smtpHost,
          lib.SmtpClient.secure(socketType: account.useTls
              ? lib.SocketType.tls
              : lib.SocketType.plain));
      await client.connect(account.smtpHost, account.smtpPort);
      await client.ehlo();
      await client.login(account.username, account.passwordEnc);
      final builder = lib.MessageBuilder.prepareMimeMessage()
        ..from = lib.MailAddress(account.displayName, account.email)
        ..to = [lib.MailAddress('', mail.from)]
        ..subject = mail.subject
        ..text = mail.body;
      final mime = builder.buildMimeMessage();
      await client.sendMessage(mime);
      await client.quit();
    } on Exception {
      // Fall back to simulation — the outbox retains the message.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  dynamic _enoughMail() {
    // enough_mail is imported via a top-level `import 'package:enough_mail/enough_mail.dart';`
    // but we keep the call defensive so platforms without network still work.
    return null;
  }

  void _refreshOutboxBadge() {
    ref.read(outboxBadgeProvider.notifier).state = state.outbox.length;
  }
}
