import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/matching/bangla_translit.dart';

/// The words on a pack, read on the phone by Google ML Kit in Bangla and
/// English (bundled models, no network).
class LabelText {
  const LabelText({required this.text, this.headline});

  /// Everything read, one line per line.
  final String text;

  /// The biggest line on the pack -- usually the brand or product name.
  final String? headline;

  static const empty = LabelText(text: '');
}

class LabelReader {
  /// English and other Latin-script print.
  final _latin = TextRecognizer(script: TextRecognitionScript.latin);

  /// Bangla print. ML Kit's "Devanagari" engine carries a Bengali-script
  /// line recogniser too and chooses the script line by line.
  final _bangla = TextRecognizer(script: TextRecognitionScript.devanagiri);
  int _seq = 0;

  Future<LabelText> read(Uint8List jpeg) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'scan_${_seq++ % 8}.jpg'));
    await file.writeAsBytes(jpeg, flush: true);
    final image = InputImage.fromFilePath(file.path);
    // Both at once; either failing leaves the other's reading.
    final (latin, bangla) = await (
      _lines(_latin, image),
      _lines(_bangla, image),
    ).wait;
    return mergeLabelLines(latin, bangla);
  }

  static Future<List<TextLine>> _lines(TextRecognizer r, InputImage image) async {
    try {
      final text = await r.processImage(image);
      return [for (final b in text.blocks) ...b.lines];
    } catch (_) {
      return const [];
    }
  }

  /// Reads a blank image once: ML Kit loads its models on the first read.
  Future<void> warmUp() async {
    await read(img.encodeJpg(img.Image(width: 64, height: 64)));
  }

  Future<void> close() async {
    await _latin.close();
    await _bangla.close();
  }
}

/// One reading from the two engines: every English line, plus the lines in
/// Bangla (the Bangla engine reads English too, less well, so its Latin lines
/// would only repeat the English engine's). The headline is the tallest line.
LabelText mergeLabelLines(List<TextLine> latin, List<TextLine> bangla) {
  final lines = [...latin, ...bangla.where((l) => isBangla(l.text))];
  TextLine? biggest;
  for (final l in lines) {
    if (biggest == null || l.boundingBox.height > biggest.boundingBox.height) {
      biggest = l;
    }
  }
  return LabelText(
    text: lines.map((l) => l.text).join('\n'),
    headline: biggest?.text.trim(),
  );
}
