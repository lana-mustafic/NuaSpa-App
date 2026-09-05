import 'package:flutter/material.dart';

import '../../core/api/services/api_service.dart';

enum ReportPdfAction { download, print }

Future<({ReportPdfKind kind, ReportPdfAction action})?> showReportPdfActionDialog(
  BuildContext context,
) {
  return showDialog<({ReportPdfKind kind, ReportPdfAction action})>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('PDF report'),
      content: const Text(
        'Choose a report. Download saves and opens the file; Print sends it to the printer.',
      ),
      actions: [
        for (final kind in ReportPdfKind.values) ...[
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, (kind: kind, action: ReportPdfAction.download)),
            icon: const Icon(Icons.download_outlined),
            label: Text('Download ${kind.label}'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, (kind: kind, action: ReportPdfAction.print)),
            icon: const Icon(Icons.print_outlined),
            label: Text('Print ${kind.label}'),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<bool> runReportPdfAction({
  required ApiService api,
  required DateTime from,
  required DateTime to,
  required ReportPdfKind kind,
  required ReportPdfAction action,
}) {
  if (action == ReportPdfAction.print) {
    return api.printReport(kind: kind, from: from, to: to);
  }
  return api.downloadReport(kind: kind, from: from, to: to);
}

String reportPdfResultMessage({
  required bool ok,
  required ReportPdfKind kind,
  required ReportPdfAction action,
}) {
  if (!ok) {
    return 'PDF ${action == ReportPdfAction.print ? 'print' : 'export'} failed. Check backend connection and sign-in.';
  }
  if (action == ReportPdfAction.print) {
    return '${kind.label} report sent to the printer.';
  }
  return '${kind.label} PDF downloaded and opened.';
}
