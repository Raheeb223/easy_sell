import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/backup.dart';
import '../../../core/db/photo_store.dart';
import '../../../core/l10n/l10n_ext.dart';

const _kLastBackup = 'last_backup_at';

/// When the shop was last backed up from this phone, or null if never.
final lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(_kLastBackup);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
});

/// Days after which Settings nudges for a fresh backup (design §4.1).
const backupNudgeDays = 7;

BackupService _service(WidgetRef ref) =>
    BackupService(ref.read(appDatabaseProvider), ref.read(photoStoreProvider));

/// Builds the backup file and opens the share sheet, so the shopkeeper can
/// save it to Drive, send it to themselves on WhatsApp, or keep it on a PC.
Future<void> shareBackupFlow(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await _service(ref).build();
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd_HHmm', 'en').format(DateTime.now());
    final file = File(p.join(dir.path, 'EasySell-backup-$stamp.zip'));
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: l10n.backup_shareSubject,
      ),
    );
    if (result.status != ShareResultStatus.dismissed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastBackup, DateTime.now().millisecondsSinceEpoch);
      ref.invalidate(lastBackupProvider);
    }
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.backup_failed)));
  }
}

/// Picks a backup file, shows what is in it, and on confirmation replaces
/// everything on this phone with it.
Future<void> restoreBackupFlow(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFiles();
  final path = picked.isEmpty ? null : picked.single.path;
  if (path == null || !context.mounted) return;
  final bytes = await File(path).readAsBytes();
  if (!context.mounted) return;

  final ({String shop, int products, int sales, DateTime? createdAt}) info;
  try {
    info = BackupService.peek(bytes);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.backup_notBackup)));
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.backup_restoreConfirmTitle),
      content: Text(
        l10n.backup_restoreConfirmBody(
          info.shop,
          info.products,
          info.sales,
          info.createdAt == null
              ? '—'
              : DateFormat.yMMMd().add_jm().format(info.createdAt!.toLocal()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.backup_restoreButton),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await _service(ref).restore(bytes);
    messenger.showSnackBar(SnackBar(content: Text(l10n.backup_restored)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.backup_failed)));
  }
}
