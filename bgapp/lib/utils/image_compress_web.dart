import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Compress an image to JPEG and resize if larger than [maxDimension].
/// Returns base64-encoded JPEG string.
/// [quality] is 0.0 – 1.0 (default 0.75 ≈ good quality, small file).
Future<String> compressImageToBase64(
  Uint8List imageBytes, {
  int maxDimension = 1024,
  double quality = 0.75,
}) async {
  final completer = Completer<String>();

  // Create a blob from the raw bytes and load into an HTMLImageElement
  final blob = html.Blob([imageBytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final img = html.ImageElement(src: url);

  img.onLoad.listen((_) {
    // Calculate scaled dimensions
    int w = img.naturalWidth;
    int h = img.naturalHeight;

    if (w > maxDimension || h > maxDimension) {
      if (w > h) {
        h = (h * maxDimension / w).round();
        w = maxDimension;
      } else {
        w = (w * maxDimension / h).round();
        h = maxDimension;
      }
    }

    // Draw onto a canvas at the target size
    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, w, h);

    // Export as JPEG with quality
    final dataUrl = canvas.toDataUrl('image/jpeg', quality);

    // Strip the "data:image/jpeg;base64," prefix
    final b64 = dataUrl.split(',').last;

    html.Url.revokeObjectUrl(url);
    completer.complete(b64);
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(url);
    // Fallback: return original as base64 without compression
    completer.complete(base64Encode(imageBytes));
  });

  return completer.future;
}

/// Compress an already-base64-encoded image.
/// Useful for re-compressing after background removal (which returns PNG).
Future<String> compressBase64Image(
  String base64Str, {
  int maxDimension = 1024,
  double quality = 0.75,
}) async {
  final bytes = base64Decode(base64Str);
  return compressImageToBase64(
    Uint8List.fromList(bytes),
    maxDimension: maxDimension,
    quality: quality,
  );
}
