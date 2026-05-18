import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'controller/capture_notifier.dart';

class CaptureDetailScreen extends ConsumerWidget {
  const CaptureDetailScreen({super.key, required this.capture});

  final Capture capture;

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
    final statusColor = _getStatusColor(capture.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture details'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(capture.localPath),
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_getStatusIcon(capture.status), color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    capture.status.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: statusColor),
                  ),
                  const Spacer(),
                  Text(
                    capture.createdAt.toLocal().toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Labels',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (capture.labels.isEmpty) const Text('No labels'),
              if (capture.labels.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: capture.labels
                      .map((l) => Chip(label: Text('${l.text} ${(l.confidence * 100).toStringAsFixed(0)}%')))
                      .toList(),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Builder(builder: (context) {
                      final isUploaded = capture.status == 'uploaded';
                      return ElevatedButton.icon(
                        onPressed: isUploaded
                            ? null
                            : () async {
                                final notifier = ref.read(captureControllerProvider.notifier);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing...')));
                                try {
                                  final ok = await notifier.syncAll();
                                  if (ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync complete')));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync failed')));
                                  }
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync error')));
                                }
                              },
                        icon: Icon(isUploaded ? Icons.cloud_done_outlined : Icons.refresh),
                        label: Text(isUploaded ? 'Synced' : 'Retry sync'),
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
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
