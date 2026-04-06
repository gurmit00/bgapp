import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Pick an image from the user's device on web.
/// [useCamera] true = prefer rear camera (mobile browsers show camera),
///             false = show file picker for gallery.
/// Returns raw image bytes, or null if cancelled.
Future<Uint8List?> pickImageWeb({bool useCamera = false}) async {
  final completer = Completer<Uint8List?>();

  final input = html.FileUploadInputElement()..accept = 'image/*';

  // On mobile browsers, capture='environment' hints at using the rear camera
  if (useCamera) {
    input.setAttribute('capture', 'environment');
  }

  input.click();

  // Listen for file selection — onChange fires when user picks a file or cancels
  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(files[0]);
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else if (result is List<int>) {
        completer.complete(Uint8List.fromList(result));
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) => completer.complete(null));
  });

  // Note: no window.onFocus cancel detection — it fires too early on first open
  // and cancels the picker before the user has a chance to take the photo.
  // The completer resolves naturally when the user picks or dismisses.

  return completer.future;
}
