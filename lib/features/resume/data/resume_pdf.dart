import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/resume_builder.dart';
import '../domain/resume_version.dart';

/// Renders resumes and cover letters as A4 PDFs.
///
/// Every template is one column of real, selectable text in reading
/// order (no tables, images or text boxes), so ATS parsers read it well.
class ResumePdf {
  const ResumePdf._();

  static PdfColor _pdf(int argb) => PdfColor.fromInt(argb);

  static _Fonts? _cache;

  /// DM Sans / DM Serif Display, downloaded once (needs internet the first
  /// time). Falls back to the built-in Helvetica/Times when offline.
  static Future<_Fonts> _fonts() async {
    if (_cache != null) return _cache!;
    try {
      final f = _Fonts(
        body: await PdfGoogleFonts.dMSansRegular(),
        bold: await PdfGoogleFonts.dMSansBold(),
        italic: await PdfGoogleFonts.dMSansItalic(),
        serif: await PdfGoogleFonts.dMSerifDisplayRegular(),
        embedded: true,
      );
      return _cache = f;
    } catch (_) {
      return _Fonts(
        body: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        serif: pw.Font.timesBold(),
        embedded: false,
      );
    }
  }

  static Future<Uint8List> resume(ResumeContent c, ResumeTemplate t) async {
    final f = await _fonts();
    final s = _Style.of(t, f);
    String tx(String v) => f.clean(v);

    final doc = pw.Document(title: '${c.name} – Resume', author: c.name);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(s.margin),
        theme: pw.ThemeData.withFont(
          base: f.body,
          bold: f.bold,
          italic: f.italic,
        ),
        build: (_) => [
          pw.Text(
            tx(c.name),
            style: pw.TextStyle(
              font: s.nameFont,
              fontSize: s.nameSize,
              color: s.ink,
            ),
          ),
          if (c.headline.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                tx(c.headline),
                style: pw.TextStyle(fontSize: s.body + 1, color: s.accent),
              ),
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            tx(c.contact.join('  |  ')),
            style: pw.TextStyle(fontSize: s.body - 1, color: s.muted),
          ),
          for (final b in c.blocks) ...[
            pw.SizedBox(height: s.gap),
            pw.Text(
              tx(b.title.toUpperCase()),
              style: pw.TextStyle(
                font: s.headingFont,
                fontSize: s.heading,
                color: s.accent,
                letterSpacing: 0.8,
              ),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2, bottom: 4),
              height: 0.8,
              color: s.rule,
            ),
            for (final i in b.items) _item(i, s, tx),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _item(ResumeItem i, _Style s, String Function(String) tx) {
    final small = pw.TextStyle(
      fontSize: s.body,
      color: s.ink,
      lineSpacing: 1.5,
    );
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: s.itemGap),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (i.heading.isNotEmpty || i.meta.isNotEmpty)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: tx(i.heading),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: s.body + 0.5,
                            color: s.ink,
                          ),
                        ),
                        // Skill rows: "Technical: Java, Python"
                        if (i.subheading.isEmpty &&
                            i.line.isNotEmpty &&
                            i.bullets.isEmpty &&
                            i.heading.isNotEmpty)
                          pw.TextSpan(text: tx(': ${i.line}'), style: small),
                      ],
                    ),
                  ),
                ),
                if (i.meta.isNotEmpty)
                  pw.Text(
                    tx(i.meta),
                    style: pw.TextStyle(fontSize: s.body - 0.5, color: s.muted),
                  ),
              ],
            ),
          if (i.subheading.isNotEmpty)
            pw.Text(
              tx(i.subheading),
              style: pw.TextStyle(
                fontStyle: pw.FontStyle.italic,
                fontSize: s.body,
                color: s.muted,
              ),
            ),
          for (final b in i.bullets)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, top: 1),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(tx('•  '), style: small),
                  pw.Expanded(child: pw.Text(tx(b), style: small)),
                ],
              ),
            ),
          // Plain lines (summary, links, list items) — skill rows are inline above.
          if (i.line.isNotEmpty &&
              !(i.subheading.isEmpty &&
                  i.bullets.isEmpty &&
                  i.heading.isNotEmpty))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: i.bullet
                  ? pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(tx('•  '), style: small),
                        pw.Expanded(child: pw.Text(tx(i.line), style: small)),
                      ],
                    )
                  : pw.Text(tx(i.line), style: small),
            ),
        ],
      ),
    );
  }

  static Future<Uint8List> coverLetter(String text, ResumeContent c) async {
    final f = await _fonts();
    String tx(String v) => f.clean(v);
    final doc = pw.Document(title: '${c.name} – Cover letter', author: c.name);
    final ink = _pdf(AppColors.charcoal.toARGB32());
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56),
        theme: pw.ThemeData.withFont(
          base: f.body,
          bold: f.bold,
          italic: f.italic,
        ),
        build: (_) => [
          pw.Text(
            tx(c.name),
            style: pw.TextStyle(font: f.serif, fontSize: 20, color: ink),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            tx(c.contact.join('  |  ')),
            style: pw.TextStyle(
              fontSize: 9,
              color: _pdf(AppColors.mutedText.toARGB32()),
            ),
          ),
          pw.SizedBox(height: 24),
          for (final para in text.split(RegExp(r'\n\s*\n')))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                tx(para.trim()),
                style: pw.TextStyle(fontSize: 11, lineSpacing: 3, color: ink),
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }
}

class _Fonts {
  _Fonts({
    required this.body,
    required this.bold,
    required this.italic,
    required this.serif,
    required this.embedded,
  });

  final pw.Font body, bold, italic, serif;
  final bool embedded;

  /// The built-in fallback fonts only cover basic Latin, so replace the
  /// few typographic characters we use.
  String clean(String s) => embedded
      ? s
      : s
            .replaceAll(RegExp('[–—]'), '-')
            .replaceAll('•', '-')
            .replaceAll(RegExp('[‘’]'), "'")
            .replaceAll(RegExp('[“”]'), '"')
            .replaceAll(RegExp(r'[^\x00-\xFF]'), '');
}

/// Per-template look. Resume templates may have their own theme
/// (CLAUDE.md §2); Modern reuses the brand green.
class _Style {
  _Style({
    required this.nameFont,
    required this.headingFont,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.rule,
    required this.margin,
    required this.nameSize,
    required this.heading,
    required this.body,
    required this.gap,
    required this.itemGap,
  });

  final pw.Font nameFont, headingFont;
  final PdfColor ink, muted, accent, rule;
  final double margin, nameSize, heading, body, gap, itemGap;

  factory _Style.of(ResumeTemplate t, _Fonts f) {
    final charcoal = ResumePdf._pdf(AppColors.charcoal.toARGB32());
    final muted = ResumePdf._pdf(AppColors.mutedText.toARGB32());
    switch (t) {
      case ResumeTemplate.classic:
        return _Style(
          nameFont: f.serif,
          headingFont: f.bold,
          ink: PdfColors.black,
          muted: PdfColors.grey700,
          accent: PdfColors.black,
          rule: PdfColors.black,
          margin: 40,
          nameSize: 22,
          heading: 10.5,
          body: 10,
          gap: 12,
          itemGap: 6,
        );
      case ResumeTemplate.modern:
        final green = ResumePdf._pdf(AppColors.botanicalGreen.toARGB32());
        return _Style(
          nameFont: f.bold,
          headingFont: f.bold,
          ink: charcoal,
          muted: muted,
          accent: green,
          rule: green,
          margin: 40,
          nameSize: 22,
          heading: 10.5,
          body: 10,
          gap: 12,
          itemGap: 6,
        );
      case ResumeTemplate.compact:
        return _Style(
          nameFont: f.bold,
          headingFont: f.bold,
          ink: charcoal,
          muted: muted,
          accent: charcoal,
          rule: ResumePdf._pdf(AppColors.stone.toARGB32()),
          margin: 28,
          nameSize: 18,
          heading: 9.5,
          body: 9,
          gap: 8,
          itemGap: 4,
        );
    }
  }
}
