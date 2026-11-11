import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/resume_builder.dart';
import '../domain/resume_version.dart';

/// Renders resumes and cover letters as A4 PDFs.
///
/// Three distinct layouts, all made of real, selectable text in reading
/// order (no images or text boxes), so ATS parsers can read them:
/// - Classic: centred serif header, double-rule headings. Safest for ATS.
/// - Modern: green header band, accent-bar headings, skill tags.
/// - Compact: side headings in a narrow left column, dense spacing.
class ResumePdf {
  const ResumePdf._();

  static Future<Uint8List> resume(ResumeContent c, ResumeTemplate t) async {
    final f = await _Fonts.load();
    final doc = pw.Document(title: '${c.name} – Resume', author: c.name);
    switch (t) {
      case ResumeTemplate.classic:
        _Classic(f).add(doc, c);
      case ResumeTemplate.modern:
        _Modern(f).add(doc, c);
      case ResumeTemplate.compact:
        _Compact(f).add(doc, c);
    }
    return doc.save();
  }

  static Future<Uint8List> coverLetter(String text, ResumeContent c) async {
    final f = await _Fonts.load();
    final doc = pw.Document(title: '${c.name} – Cover letter', author: c.name);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(56),
      theme: f.theme(f.sans),
      build: (_) => [
        pw.Text(f.tx(c.name),
            style: pw.TextStyle(font: f.display, fontSize: 20, color: _charcoal)),
        pw.SizedBox(height: 2),
        pw.Text(f.tx(c.contact.join('  ·  ')),
            style: pw.TextStyle(fontSize: 9, color: _muted)),
        pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 16),
            height: 1.2,
            color: _green),
        for (final para in text.split(RegExp(r'\n\s*\n')))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(f.tx(para.trim()),
                style: pw.TextStyle(fontSize: 11, lineSpacing: 3, color: _charcoal)),
          ),
      ],
    ));
    return doc.save();
  }
}

// Template palettes. Resume templates may have their own theme
// (CLAUDE.md §2); these reuse the brand tokens.
final _green = PdfColor.fromInt(AppColors.botanicalGreen.toARGB32());
final _charcoal = PdfColor.fromInt(AppColors.charcoal.toARGB32());
final _muted = PdfColor.fromInt(AppColors.mutedText.toARGB32());
final _stone = PdfColor.fromInt(AppColors.stone.toARGB32());
final _ivory = PdfColor.fromInt(AppColors.ivory.toARGB32());
final _sage = PdfColor.fromInt(AppColors.softSage.toARGB32());

/// A skill row like "Technical: Java, Python" (heading + line only).
bool _isSkillRow(ResumeItem i) =>
    i.heading.isNotEmpty &&
    i.line.isNotEmpty &&
    i.subheading.isEmpty &&
    i.bullets.isEmpty &&
    i.meta.isEmpty;

class _Fonts {
  _Fonts(this.sans, this.sansBold, this.sansItalic, this.serif, this.serifBold,
      this.serifItalic, this.display, this.embedded);

  final pw.Font sans, sansBold, sansItalic, serif, serifBold, serifItalic, display;
  final bool embedded;

  static _Fonts? _cache;

  /// DM Sans, Lora and DM Serif Display, downloaded once (internet needed
  /// the first time). Falls back to built-in Helvetica/Times when offline.
  static Future<_Fonts> load() async {
    if (_cache != null) return _cache!;
    try {
      final fonts = await Future.wait([
        PdfGoogleFonts.dMSansRegular(),
        PdfGoogleFonts.dMSansBold(),
        PdfGoogleFonts.dMSansItalic(),
        PdfGoogleFonts.loraRegular(),
        PdfGoogleFonts.loraBold(),
        PdfGoogleFonts.loraItalic(),
        PdfGoogleFonts.dMSerifDisplayRegular(),
      ]);
      return _cache = _Fonts(fonts[0], fonts[1], fonts[2], fonts[3], fonts[4],
          fonts[5], fonts[6], true);
    } catch (_) {
      return _Fonts(pw.Font.helvetica(), pw.Font.helveticaBold(),
          pw.Font.helveticaOblique(), pw.Font.times(), pw.Font.timesBold(),
          pw.Font.timesItalic(), pw.Font.timesBold(), false);
    }
  }

  pw.ThemeData theme(pw.Font base) => base == serif
      ? pw.ThemeData.withFont(base: serif, bold: serifBold, italic: serifItalic)
      : pw.ThemeData.withFont(base: sans, bold: sansBold, italic: sansItalic);

  /// The built-in fallback fonts only cover basic Latin.
  String tx(String s) => embedded
      ? s
      : s
          .replaceAll(RegExp('[–—]'), '-')
          .replaceAll('•', '-')
          .replaceAll(RegExp('[‘’]'), "'")
          .replaceAll(RegExp('[“”]'), '"')
          .replaceAll('·', '|')
          .replaceAll(RegExp(r'[^\x00-\xFF]'), '');
}

/// Shared pieces: an entry's heading row, subheading and bullets.
abstract class _Layout {
  _Layout(this.f);
  final _Fonts f;

  double get size;
  PdfColor get ink => _charcoal;
  PdfColor get metaColor => _muted;
  /// The bullet in front of list lines.
  pw.Widget bullet() => pw.Text(f.tx('•'), style: text);

  pw.TextStyle get text =>
      pw.TextStyle(fontSize: size, color: ink, lineSpacing: 1.4);

  pw.Widget headingRow(ResumeItem i, {bool inlineSub = false}) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(
                    text: f.tx(i.heading),
                    style: pw.TextStyle(
                        fontSize: size + 0.5,
                        fontWeight: pw.FontWeight.bold,
                        color: ink)),
                if (inlineSub && i.subheading.isNotEmpty)
                  pw.TextSpan(
                      text: f.tx('  ·  ${i.subheading}'),
                      style: pw.TextStyle(
                          fontSize: size,
                          fontStyle: pw.FontStyle.italic,
                          color: _muted)),
              ]),
            ),
          ),
          if (i.meta.isNotEmpty)
            pw.Text(f.tx(i.meta),
                style: pw.TextStyle(
                    fontSize: size - 0.5,
                    fontStyle: pw.FontStyle.italic,
                    color: metaColor)),
        ],
      );

  pw.Widget bulletLine(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 8, top: 1.2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 9, child: bullet()),
            pw.Expanded(child: pw.Text(f.tx(s), style: text)),
          ],
        ),
      );

  /// A standard entry (job, project, education, list item, paragraph).
  pw.Widget entry(ResumeItem i, {bool inlineSub = false, double gap = 6}) {
    if (_isSkillRow(i)) {
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: gap / 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: f.tx('${i.heading}: '),
                style: text.copyWith(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: f.tx(i.line), style: text),
          ]),
        ),
      );
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: gap),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (i.heading.isNotEmpty || i.meta.isNotEmpty)
            headingRow(i, inlineSub: inlineSub),
          if (i.subheading.isNotEmpty && !inlineSub)
            pw.Text(f.tx(i.subheading),
                style: pw.TextStyle(
                    fontSize: size,
                    fontStyle: pw.FontStyle.italic,
                    color: _muted)),
          for (final b in i.bullets) bulletLine(b),
          if (i.line.isNotEmpty)
            i.bullet
                ? bulletLine(i.line)
                : pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1),
                    child: pw.Text(f.tx(i.line), style: text)),
        ],
      ),
    );
  }

  void add(pw.Document doc, ResumeContent c);
}

/// Classic: centred serif header, small-caps headings over a double rule.
class _Classic extends _Layout {
  _Classic(super.f);

  @override
  double get size => 10;
  @override
  PdfColor get ink => PdfColors.black;
  @override
  PdfColor get metaColor => PdfColors.grey800;

  pw.Widget _heading(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(f.tx(title.toUpperCase()),
                style: pw.TextStyle(
                    font: f.serifBold, fontSize: 10.5, letterSpacing: 1.6)),
            pw.SizedBox(height: 2),
            pw.Container(height: 0.9, color: PdfColors.black),
            pw.SizedBox(height: 1.2),
            pw.Container(height: 0.4, color: PdfColors.black),
          ],
        ),
      );

  @override
  void add(pw.Document doc, ResumeContent c) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 46, vertical: 40),
      theme: f.theme(f.serif),
      build: (_) => [
        pw.Center(
          child: pw.Text(f.tx(c.name.toUpperCase()),
              style: pw.TextStyle(
                  font: f.serifBold, fontSize: 21, letterSpacing: 2.2)),
        ),
        if (c.headline.isNotEmpty)
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(f.tx(c.headline),
                  style: pw.TextStyle(
                      font: f.serifItalic,
                      fontSize: 11,
                      color: PdfColors.grey800)),
            ),
          ),
        pw.SizedBox(height: 5),
        pw.Center(
          child: pw.Text(f.tx(c.contact.join('  ·  ')),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
        ),
        for (final b in c.blocks) ...[
          _heading(b.title),
          for (final i in b.items) entry(i),
        ],
      ],
    ));
  }
}

/// Modern: green header band, accent-bar headings, skills as tags.
class _Modern extends _Layout {
  _Modern(super.f);

  @override
  double get size => 9.8;
  @override
  PdfColor get metaColor => _green;
  @override
  pw.Widget bullet() => pw.Padding(
        padding: pw.EdgeInsets.only(top: size * 0.45),
        child: pw.Container(width: 3.4, height: 3.4, color: _green),
      );

  pw.Widget _header(ResumeContent c) => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: pw.BoxDecoration(
            color: _green, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(f.tx(c.name),
                style: pw.TextStyle(
                    font: f.sansBold,
                    fontSize: 24,
                    color: _ivory,
                    letterSpacing: 0.3)),
            if (c.headline.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(f.tx(c.headline),
                    style: pw.TextStyle(fontSize: 12, color: _sage)),
              ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 14,
              runSpacing: 3,
              children: [
                for (final item in c.contact)
                  pw.Text(f.tx(item),
                      style: pw.TextStyle(fontSize: 8.8, color: _ivory)),
              ],
            ),
          ],
        ),
      );

  pw.Widget _heading(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 13, color: _green),
          pw.SizedBox(width: 7),
          pw.Text(f.tx(title),
              style: pw.TextStyle(font: f.sansBold, fontSize: 12, color: _green)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(height: 0.6, color: _stone)),
        ]),
      );

  pw.Widget _tags(ResumeItem i) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 70,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2.5),
                child: pw.Text(f.tx(i.heading),
                    style:
                        pw.TextStyle(font: f.sansBold, fontSize: size, color: ink)),
              ),
            ),
            pw.Expanded(
              child: pw.Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final s in i.line.split(', '))
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: _ivory,
                        border: pw.Border.all(color: _sage, width: 0.6),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(f.tx(s),
                          style: pw.TextStyle(fontSize: size - 0.8, color: ink)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  void add(pw.Document doc, ResumeContent c) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 30),
      theme: f.theme(f.sans),
      build: (_) => [
        _header(c),
        for (final b in c.blocks) ...[
          _heading(b.title),
          for (final i in b.items)
            b.kind == ResumeSectionKind.skills && _isSkillRow(i)
                ? _tags(i)
                : entry(i),
        ],
      ],
    ));
  }
}

/// Compact: name left, contact stacked right; section titles sit in a
/// narrow left column beside their entries. Dense, fits more per page.
class _Compact extends _Layout {
  _Compact(super.f);

  static const _side = 88.0;

  @override
  double get size => 8.8;

  pw.Widget _header(ResumeContent c) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(f.tx(c.name),
                    style: pw.TextStyle(font: f.display, fontSize: 22, color: ink)),
                if (c.headline.isNotEmpty)
                  pw.Text(f.tx(c.headline.toUpperCase()),
                      style: pw.TextStyle(
                          font: f.sansBold,
                          fontSize: 8.5,
                          color: _green,
                          letterSpacing: 1.4)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final item in c.contact)
                pw.Text(f.tx(item),
                    style: pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
        ],
      );

  /// One row of the grid: the section title only beside its first entry.
  pw.Widget _row(String? title, pw.Widget child) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: _side,
            child: title == null
                ? pw.SizedBox()
                : pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1, right: 8),
                    child: pw.Text(f.tx(title.toUpperCase()),
                        style: pw.TextStyle(
                            font: f.sansBold,
                            fontSize: 8,
                            color: _green,
                            letterSpacing: 1)),
                  ),
          ),
          pw.Expanded(child: child),
        ],
      );

  @override
  void add(pw.Document doc, ResumeContent c) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 28),
      theme: f.theme(f.sans),
      build: (_) => [
        _header(c),
        pw.Container(
            margin: const pw.EdgeInsets.only(top: 8, bottom: 2),
            height: 1.4,
            color: ink),
        for (final b in c.blocks) ...[
          pw.Container(
              margin: const pw.EdgeInsets.only(top: 6, bottom: 5),
              height: 0.5,
              color: _stone),
          for (var n = 0; n < b.items.length; n++)
            _row(n == 0 ? b.title : null,
                entry(b.items[n], inlineSub: true, gap: 4)),
        ],
      ],
    ));
  }
}
