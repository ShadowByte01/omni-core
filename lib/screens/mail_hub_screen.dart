import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/connectivity_controller.dart' as conn;
import '../models/mail_message.dart';
import '../providers/providers.dart';
import '../services/mail_service.dart';
import '../theme/sketchy_constants.dart';
import '../widgets/sketchy_button.dart';
import '../widgets/sketchy_card.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/sketchy_icons.dart';

/// Mail Hub — sketched letters stacked on top of each other, each with a
/// 1–5 sketched-star Mail Rate score. Offline Outbox holds drafted mails with a
/// paper-plane icon that animates flying away the moment you go online.
class MailHubScreen extends ConsumerStatefulWidget {
  const MailHubScreen({super.key});

  @override
  ConsumerState<MailHubScreen> createState() => _MailHubScreenState();
}

class _MailHubScreenState extends ConsumerState<MailHubScreen> {
  _Folder _folder = _Folder.inbox;

  @override
  Widget build(BuildContext context) {
    final mail = ref.watch(mailServiceProvider);
    final connectivity = ref.watch(conn.connectivityProvider);
    final list = _folder == _Folder.outbox
        ? mail.outbox
        : mail.inbox.where((m) {
            if (_folder == _Folder.starred) return m.isStarred;
            return true;
          }).toList();

    return Column(
      children: [
        // Folder tabs.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              _FolderTab(
                label: 'Inbox',
                icon: SketchIconType.inbox,
                count: mail.inbox.length,
                selected: _folder == _Folder.inbox,
                onTap: () => setState(() => _folder = _Folder.inbox),
              ),
              const SizedBox(width: 8),
              _FolderTab(
                label: 'Outbox',
                icon: SketchIconType.outbox,
                count: mail.outbox.length,
                selected: _folder == _Folder.outbox,
                badge: mail.outbox.isNotEmpty,
                onTap: () => setState(() => _folder = _Folder.outbox),
              ),
              const SizedBox(width: 8),
              _FolderTab(
                label: 'Starred',
                icon: SketchIconType.star,
                count: mail.inbox.where((m) => m.isStarred).length,
                selected: _folder == _Folder.starred,
                onTap: () => setState(() => _folder = _Folder.starred),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _compose(),
                child: const Tooltip(
                  message: 'Compose',
                  child: SketchIcon(SketchIconType.pencil, size: 28),
                ),
              ),
            ],
          ),
        ),
        if (_folder == _Folder.outbox)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _OutboxBanner(
              online:
                  connectivity == conn.ConnectivityStatus.online,
              sending: mail.sending,
              onSend: () => ref
                  .read(mailServiceProvider.notifier)
                  .dispatchOutbox(),
            ),
          ),
        Expanded(
          child: mail.loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SketchIcon(SketchIconType.mail, size: 64),
                          const SizedBox(height: 12),
                          Text(
                            _folder == _Folder.outbox
                                ? 'Outbox is empty — drafted mails will wait here.'
                                : 'No letters here.',
                            style:
                                Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _LetterCard(
                        message: list[i],
                        isOutbox: _folder == _Folder.outbox,
                        online: connectivity ==
                            conn.ConnectivityStatus.online,
                        index: i,
                        onTap: () => _open(list[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  void _compose() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ComposeSheet(),
    );
  }

  void _open(MailMessage m) {
    ref.read(mailServiceProvider.notifier).markRead(m.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReaderSheet(message: m),
    );
  }
}

enum _Folder { inbox, outbox, starred }

class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final SketchIconType icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink =
        isDark ? SketchPalette.chalkInk : SketchPalette.inkLight;
    return GestureDetector(
      onTap: onTap,
      child: SketchyContainer(
        fillColor:
            selected ? ink.withValues(alpha: 0.08) : Colors.transparent,
        strokeColor: selected ? ink : Colors.transparent,
        strokeWidth: 1.5,
        borderRadius: 12,
        roughness: selected ? 1.0 : 0.4,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SketchIcon(icon,
                size: 20,
                color: ink.withValues(alpha: selected ? 1.0 : 0.6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: ink,
              ),
            ),
            const SizedBox(width: 6),
            if (badge && count > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? SketchPalette.chalkboard
                        : SketchPalette.paperLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutboxBanner extends StatelessWidget {
  const _OutboxBanner({
    required this.online,
    required this.sending,
    required this.onSend,
  });
  final bool online;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SketchyContainer(
      roughness: 0.8,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const SketchIcon(SketchIconType.paperPlane, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              online
                  ? 'Online — paper planes are ready to fly.'
                  : 'Offline — your letters will wait here until you reconnect.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (online)
            SketchyButton(
              label: sending ? 'Sending…' : 'Send all',
              icon: const SketchIcon(SketchIconType.paperPlane, size: 16),
              disabled: sending,
              onPressed: sending ? null : onSend,
            ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.message,
    required this.isOutbox,
    required this.online,
    required this.index,
    required this.onTap,
  });

  final MailMessage message;
  final bool isOutbox;
  final bool online;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: index == 0 ? 0 : 6,
        bottom: 6,
        // Slight horizontal stagger so letters look stacked.
        left: (index % 3) * 4.0,
        right: (2 - index % 3) * 4.0,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: SketchyCard(
          shadow: true,
          roughness: 0.9,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOutbox)
                const Padding(
                  padding: EdgeInsets.only(right: 10, top: 2),
                  child: SketchIcon(SketchIconType.paperPlane, size: 24),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 10, top: 2),
                  child: SketchIcon(SketchIconType.mail, size: 24),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.fromName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _MailRateStars(rate: message.mailRate),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.subject,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.preview,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (message.isStarred)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SketchIcon(SketchIconType.starFilled,
                                size: 16),
                          ),
                        if (message.hasAttachment)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SketchIcon(SketchIconType.fileDoc, size: 16),
                          ),
                        Text(
                          _timeAgo(message.receivedAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (isOutbox && online) ...[
                          const Spacer(),
                          const SketchIcon(SketchIconType.paperPlane, size: 16)
                              .animate(onPlay: (c) => c.repeat())
                              .moveX(
                                begin: 0,
                                end: 8,
                                duration: 700.ms,
                              )
                              .then()
                              .moveX(begin: 8, end: 0, duration: 300.ms),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: SketchPalette.smooth)
            .slideY(begin: 0.08, end: 0, duration: SketchPalette.smooth),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _MailRateStars extends StatelessWidget {
  const _MailRateStars({required this.rate});
  final int rate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          SketchIcon(
            i <= rate ? SketchIconType.starFilled : SketchIconType.star,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: i <= rate ? 1.0 : 0.3),
          ),
      ],
    );
  }
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet();

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _to = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compose letter',
                style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 10),
            _Field(label: 'To', controller: _to, hint: 'friend@omnicore.local'),
            const SizedBox(height: 8),
            _Field(
                label: 'Subject', controller: _subject, hint: 'Sketchy hello'),
            const SizedBox(height: 8),
            SketchyContainer(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _body,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write your letter…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SketchyButton(
                    label: 'Queue in Outbox',
                    icon:
                        const SketchIcon(SketchIconType.paperPlane, size: 18),
                    bold: true,
                    expand: true,
                    onPressed: () async {
                      await ref.read(mailServiceProvider.notifier).compose(
                            to: _to.text,
                            subject: _subject.text.isEmpty
                                ? '(no subject)'
                                : _subject.text,
                            body: _body.text,
                          );
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });
  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SketchyContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderSheet extends ConsumerWidget {
  const _ReaderSheet({required this.message});
  final MailMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (context, controller) {
        return SketchyContainer(
          fillColor: isDark
              ? SketchPalette.chalkboard
              : SketchPalette.paperLight,
          roughness: 0.6,
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(message.subject,
                        style: theme.textTheme.displaySmall),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const SketchIcon(SketchIconType.close, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.fromName,
                            style: theme.textTheme.titleMedium),
                        Text(message.from,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  _MailRateStars(rate: message.mailRate),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref
                        .read(mailServiceProvider.notifier)
                        .toggleStar(message.id),
                    child: SketchIcon(
                      message.isStarred
                          ? SketchIconType.starFilled
                          : SketchIconType.star,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SketchyContainer(
                padding: const EdgeInsets.all(14),
                child: Text(message.body, style: theme.textTheme.bodyLarge),
              ),
              if (message.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Attachments', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final a in message.attachments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SketchIcon(SketchIconType.fileDoc, size: 20),
                        const SizedBox(width: 8),
                        Text(a, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
