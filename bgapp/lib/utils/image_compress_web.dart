import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Compress an image to JPEG and resize if larger than [maxDimension].
/// Returns base64-encoded JPEG string.
/// [quality] is 0.0 – 1.0 (default 0.75 ≈ good quality, small file).
/// Compress and resize image to exactly [targetW]×[targetH] JPEG.
/// Product centred, white background, quality 0.92 — matches Shopify product image format (756×1008).
/// [brightness] and [contrast] are CSS filter multipliers (1.0 = no change).
Future<String> compressImageToBase64(
  Uint8List imageBytes, {
  int maxDimension = 1024, // ignored — kept for API compatibility
  double quality = 0.92,
  int targetW = 756,
  int targetH = 1008,
  double brightness = 1.10, // +10% brightness — compensates for phone camera dark shots
  double contrast = 1.15,   // +15% contrast  — makes product pop against background
}) async {
  final completer = Completer<String>();

  final blob = html.Blob([imageBytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final img = html.ImageElement(src: url);

  img.onLoad.listen((_) {
    final srcW = img.naturalWidth;
    final srcH = img.naturalHeight;

    // Scale to fit inside target while keeping aspect ratio
    final scale = (targetW / srcW) < (targetH / srcH)
        ? targetW / srcW
        : targetH / srcH;
    final drawW = (srcW * scale).round();
    final drawH = (srcH * scale).round();

    // Centre on white canvas
    final offsetX = ((targetW - drawW) / 2).round();
    final offsetY = ((targetH - drawH) / 2).round();

    final canvas = html.CanvasElement(width: targetW, height: targetH);
    final ctx = canvas.context2D;
    ctx.fillStyle = '#FFFFFF';                                                          // white background
    ctx.fillRect(0, 0, targetW, targetH);
    ctx.filter = 'brightness($brightness) contrast($contrast)';                         // enhance for product shots
    ctx.drawImageScaled(img, offsetX, offsetY, drawW, drawH);                           // centred product

    final dataUrl = canvas.toDataUrl('image/jpeg', quality);
    html.Url.revokeObjectUrl(url);
    completer.complete(dataUrl.split(',').last);
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(url);
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

/// Resize a base64 PNG to exactly [targetW]×[targetH], centred on a transparent canvas.
/// Keeps transparency — use after background removal (JPEG would destroy alpha).
/// Defaults to 756×1008 (3:4 portrait) to match existing Shopify product images.
/// [brightness] and [contrast] are CSS filter multipliers (1.0 = no change).
Future<String> resizeBase64Png(
  String base64Str, {
  int targetW = 756,
  int targetH = 1008,
  double brightness = 1.10, // +10% brightness
  double contrast = 1.15,   // +15% contrast
}) async {
  final completer = Completer<String>();
  final bytes = base64Decode(base64Str);
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final img = html.ImageElement(src: url);

  img.onLoad.listen((_) {
    final srcW = img.naturalWidth;
    final srcH = img.naturalHeight;

    // Scale to fit inside target while keeping aspect ratio
    final scale = (targetW / srcW) < (targetH / srcH)
        ? targetW / srcW
        : targetH / srcH;
    final drawW = (srcW * scale).round();
    final drawH = (srcH * scale).round();

    // Centre on the target canvas
    final offsetX = ((targetW - drawW) / 2).round();
    final offsetY = ((targetH - drawH) / 2).round();

    final canvas = html.CanvasElement(width: targetW, height: targetH);
    final ctx = canvas.context2D;
    ctx.clearRect(0, 0, targetW, targetH);                                    // transparent background
    ctx.filter = 'brightness($brightness) contrast($contrast)';               // enhance product colours
    ctx.drawImageScaled(img, offsetX, offsetY, drawW, drawH);                 // centred product
    final dataUrl = canvas.toDataUrl('image/png');                            // PNG keeps transparency
    html.Url.revokeObjectUrl(url);
    completer.complete(dataUrl.split(',').last);
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(url);
    completer.complete(base64Str); // fallback: return as-is
  });

  return completer.future;
}
