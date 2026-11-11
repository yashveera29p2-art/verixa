import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/theme.dart';
import '../application/resume_builder_controller.dart';

/// Shows the generated PDF with Share and Print (feature 10).
class ResumePreviewScreen extends ConsumerWidget {
  const ResumePreviewScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(resumeVersionProvider(id)).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(title: Text(version?.name ?? 'Preview')),
        body: version == null
            ? const _Loading()
            : watchResumeContent(ref, version).when(
                loading: () => const _Loading(),
                error: (_, _) =>
                    const Center(child: Text('Couldn’t load your profile.')),
                data: (content) => PdfDocumentPreview(
                  generate: () =>
                      ref.read(resumeExporterProvider).pdf(content, version),
                  fileName: '${ResumeExporter.fileBase(content, version)}.pdf',
                  cacheKey: '${version.template.name}${content.hashCode}',
                ),
              ),
      ),
    );
  }
}

/// A PdfPreview with the app's colours and only Share and Print.
class PdfDocumentPreview extends StatelessWidget {
  const PdfDocumentPreview({
    super.key,
    required this.generate,
    required this.fileName,
    this.cacheKey,
  });

  final Future<Uint8List> Function() generate;
  final String fileName;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      key: ValueKey(cacheKey),
      build: (_) => generate(),
      pdfFileName: fileName,
      initialPageFormat: PdfPageFormat.a4,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      scrollViewDecoration: const BoxDecoration(color: AppColors.ivory),
      pdfPreviewPageDecoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.stone),
      ),
      loadingWidget: const _Loading(),
      onError: (context, _) => const Center(
        child: Text('Couldn’t create the PDF. Please try again.'),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: AppColors.botanicalGreen),
  );
}
