import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/presentation/controller/capture_notifier.dart';

class CaptureListScreen extends ConsumerWidget {
  const CaptureListScreen({super.key});

  Color _getStatusColor(String status) {
    return switch (status) {
      'uploaded' => Colors.green,
      'uploading' => Colors.blue,
      'failed' => Colors.red,
      _ => Colors.orange,
    };
  }

  IconData _getStatusIcon(String status) {
    return switch (status) {
      'uploaded' => Icons.cloud_done_outlined,
      'uploading' => Icons.cloud_upload_outlined,
      'failed' => Icons.error_outline,
      _ => Icons.schedule_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(captureControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captured photos'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.capture),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(captureControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: capturesAsync.when(
            data: (captures) {
              if (captures.isEmpty) {
                return const Center(
                  child: Text('No photos captured yet.'),
                );
              }

              return ListView.separated(
                itemCount: captures.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final capture = captures[index];
                  return _CaptureListTile(
                    capture: capture,
                    statusColor: _getStatusColor(capture.status),
                    statusIcon: _getStatusIcon(capture.status),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Failed to load captures: $error'),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureListTile extends StatelessWidget {
  const _CaptureListTile({
    required this.capture,
    required this.statusColor,
    required this.statusIcon,
  });

  final Capture capture;
  final Color statusColor;
  final IconData statusIcon;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = capture.labels.isEmpty ? 'No label' : capture.labels.first.text;
    final secondaryText = capture.labels.isEmpty
        ? 'No labels available'
        : '${capture.labels.length} label${capture.labels.length == 1 ? '' : 's'}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push(AppRoutes.captureDetail, extra: capture),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(capture.localPath),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 72,
                      height: 72,
                      color: AppColors.surfaceContainer,
                      child: const Icon(Icons.image_outlined),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondaryText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      capture.createdAt.toLocal().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Status: ${capture.status}',
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    capture.status == 'pending' ? 'Pending sync' : capture.status,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}