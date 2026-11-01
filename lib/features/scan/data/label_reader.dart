import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// What is printed on a pack, read on the phone by Google ML Kit: the words
/// (Latin script) and any barcode. No network.
class LabelText {
  const LabelText({required this.text, this.headline, this.barcodes = const []});

  /// Everything read, one line per line.
  final String text;

  /// The biggest line on the pack -- usually the brand or product name.
  final String? headline;

  /// Retail barcodes (EAN/UPC/Code 128) found on the pack.
  final List<String> barcodes;

  static const empty = LabelText(text: '');
}

class LabelReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcodes = BarcodeScanner(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upca,
      BarcodeFormat.upce,
      BarcodeFormat.code128,
    ],
  );
  int _seq = 0;

  Future<LabelText> read(Uint8List jpeg) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'scan_${_seq++ % 8}.jpg'));
    await file.writeAsBytes(jpeg, flush: true);
    final image = InputImage.fromFilePath(file.path);
    // Either reader failing leaves the other's result.
    final codesF = _barcodes.processImage(image).then(
          (bs) => [
            for (final b in bs)
              if (b.rawValue case final String v when v.trim().isNotEmpty) v.trim(),
          ],
          onError: (_) => const <String>[],
        );
    final RecognizedText r;
    try {
      r = await _recognizer.processImage(image);
    } catch (_) {
      return LabelText(text: '', barcodes: await codesF);
    }
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
    return LabelText(
      text: lines.join('\n'),
      headline: biggest?.text.trim(),
      barcodes: await codesF,
    );
  }

  /// Reads a blank image once: ML Kit loads its models on the first read.
  Future<void> warmUp() async {
    await read(img.encodeJpg(img.Image(width: 64, height: 64)));
  }

  Future<void> close() async {
    await _recognizer.close();
    await _barcodes.close();
  }
}
