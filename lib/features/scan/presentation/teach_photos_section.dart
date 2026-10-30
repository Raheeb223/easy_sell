import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/widgets/app_card.dart';
import '../../inventory/domain/product.dart';
import '../data/embedding_store.dart';

/// The photos EasySell Vision knows a product by (design §5a.2). Two or three
/// photos from different sides are enough; every confirmed scan adds more.
final taughtPhotosProvider = FutureProvider.autoDispose
    .family<List<TaughtPhoto>, String>((ref, productId) {
      ref.watch(taughtCountsProvider);
      return ref.watch(embeddingStoreProvider).photosOf(productId);
    });

class TeachPhotosSection extends ConsumerStatefulWidget {
  const TeachPhotosSection({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<TeachPhotosSection> createState() => _TeachPhotosSectionState();
}

class _TeachPhotosSectionState extends ConsumerState<TeachPhotosSection> {
  bool _busy = false;

  Future<void> _takePhoto() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (shot == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final embedder = await ref.read(visionEmbedderProvider.future);
      final e = await embedder.embedJpeg(await shot.readAsBytes());
      await ref
          .read(embeddingStoreProvider)
          .learn(widget.product.id, e, source: 'enroll');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.teach_failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(TaughtPhoto photo) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.teach_removeTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.teach_remove),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(embeddingStoreProvider).forget(photo.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final photos =
        ref.watch(taughtPhotosProvider(widget.product.id)).value ??
        const <TaughtPhoto>[];
    final enough = photos.length >= 2;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enough ? Icons.auto_awesome : Icons.photo_camera_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.teach_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              photos.isEmpty
                  ? l10n.teach_none
                  : l10n.teach_count(photos.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enough
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final ph = photos[i];
                    return GestureDetector(
                      onLongPress: () => _remove(ph),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            if (ph.path != null)
                              Image.file(
                                File(ph.path!),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                cacheWidth: 144,
                              )
                            else
                              const SizedBox(width: 72, height: 72),
                            if (ph.fromScan)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  size: 14,
                                  color: Colors.white,
                                  semanticLabel: l10n.teach_fromScan,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _takePhoto,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_busy ? l10n.teach_learning : l10n.teach_add),
            ),
          ],
        ),
      ),
    );
  }
}
