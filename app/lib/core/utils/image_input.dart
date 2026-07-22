import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final Uint8List bytes;
  final String mediaType;
  const PickedImage(this.bytes, this.mediaType);
}

/// Picks an image (camera or gallery), downsizes to ~1024px / JPEG 80% to keep
/// Claude image tokens and upload size low. Returns null if the user cancels.
Future<PickedImage?> pickAndCompress(ImageSource source) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 90,
  );
  if (file == null) return null;

  final raw = await file.readAsBytes();
  final compressed = await FlutterImageCompress.compressWithList(
    raw,
    minWidth: 1024,
    minHeight: 1024,
    quality: 80,
    format: CompressFormat.jpeg,
  );
  return PickedImage(compressed, 'image/jpeg');
}
