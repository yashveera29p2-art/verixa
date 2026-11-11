import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A resume file chosen by the user.
class PickedResume {
  const PickedResume({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Opens the system file picker for PDF / DOCX resumes.
class ResumeFilePicker {
  const ResumeFilePicker();

  static const extensions = ['pdf', 'docx'];

  /// Null when the user cancels.
  Future<PickedResume?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
      dialogTitle: 'Choose your resume',
    );
    if (file == null) return null;
    return PickedResume(name: file.name, bytes: await file.readAsBytes());
  }
}
