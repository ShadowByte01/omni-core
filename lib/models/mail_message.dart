import 'package:equatable/equatable.dart';

/// Status of an email in the offline-first Mail Hub.
enum MailStatus { inbox, read, outbox, sent, draft }

extension MailStatusX on MailStatus {
  String get label {
    switch (this) {
      case MailStatus.inbox:
        return 'Inbox';
      case MailStatus.read:
        return 'Read';
      case MailStatus.outbox:
        return 'Outbox';
      case MailStatus.sent:
        return 'Sent';
      case MailStatus.draft:
        return 'Draft';
    }
  }
}

/// A sketched letter in the Mail Hub.
class MailMessage extends Equatable {
  const MailMessage({
    required this.id,
    required this.from,
    required this.fromName,
    required this.subject,
    required this.preview,
    required this.body,
    required this.receivedAt,
    required this.status,
    this.mailRate = 0,
    this.isStarred = false,
    this.hasAttachment = false,
    this.attachments = const [],
  });

  final String id;
  final String from;
  final String fromName;
  final String subject;
  final String preview;
  final String body;
  final DateTime receivedAt;
  final MailStatus status;
  final int mailRate; // 0-5 sketched stars
  final bool isStarred;
  final bool hasAttachment;
  final List<String> attachments;

  MailMessage copyWith({
    MailStatus? status,
    int? mailRate,
    bool? isStarred,
  }) {
    return MailMessage(
      id: id,
      from: from,
      fromName: fromName,
      subject: subject,
      preview: preview,
      body: body,
      receivedAt: receivedAt,
      status: status ?? this.status,
      mailRate: mailRate ?? this.mailRate,
      isStarred: isStarred ?? this.isStarred,
      hasAttachment: hasAttachment,
      attachments: attachments,
    );
  }

  @override
  List<Object?> get props => [
        id,
        from,
        subject,
        receivedAt,
        status,
        mailRate,
        isStarred,
      ];
}

/// An SMTP/IMAP account config stored locally (synced if authenticated).
class MailAccount extends Equatable {
  const MailAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
    required this.username,
    required this.passwordEnc,
    required this.useTls,
  });

  final String id;
  final String email;
  final String displayName;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;
  final String username;
  final String passwordEnc; // obfuscated; real apps should use secure storage
  final bool useTls;

  @override
  List<Object?> get props =>
      [id, email, displayName, imapHost, smtpHost, username];
}
