import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The words on a pack, read on the phone by Google ML Kit (Latin script,
/// bundled model, no network).
class LabelText {
  const LabelText({required this.text, this.headline});

  /// Everything read, one line per line.
  final String text;

  /// The biggest line on the pack -- usually the brand or product name.
  final String? headline;

  static const empty = LabelText(text: '');
}

class LabelReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  int _seq = 0;

  Future<LabelText> read(Uint8List jpeg) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'scan_${_seq++ % 8}.jpg'));
    await file.writeAsBytes(jpeg, flush: true);
    final r = await _recognizer.processImage(InputImage.fromFilePath(file.path));
    TextLine? biggest;
    final lines = <String>[];
    for (final b in r.blocks) {
      for (final l in b.lines) {
        lines.add(l.text);
        if (biggest == null ||
            l.boundingBox.height > biggest.boundingBox.height) {
          biggest = l;
        }
      }
    }
    return LabelText(text: lines.join('\n'), headline: biggest?.text.trim());
  }

  /// Reads a blank image once: ML Kit loads its model on the first read.
  Future<void> warmUp() async {
    await read(img.encodeJpg(img.Image(width: 64, height: 64)));
  }

  Future<void> close() => _recognizer.close();
}
