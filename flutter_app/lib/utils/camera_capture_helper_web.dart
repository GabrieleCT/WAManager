import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'camera_capture_helper.dart';

Future<CapturedPhoto?> capturePhotoFromCamera() async {
  final completer = Completer<CapturedPhoto?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..setAttribute('capture', 'environment')
    ..style.display = 'none';

  html.document.body?.children.add(input);

  void cleanup() {
    input.remove();
  }

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      cleanup();
      final result = reader.result;
      Uint8List? bytes;
      if (result is Uint8List) {
        bytes = result;
      } else if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else if (result is List<int>) {
        bytes = Uint8List.fromList(result);
      }
      if (bytes == null || bytes.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final rawName = file.name.trim();
      final name = rawName.isNotEmpty
          ? rawName
          : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (!completer.isCompleted) {
        completer.complete(CapturedPhoto(name: name, bytes: bytes));
      }
    });
    reader.onError.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsArrayBuffer(file);
  });

  // Gestisce eventuale chiusura senza selezione su alcuni browser
  html.window.onFocus.first.then((_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted && (input.files == null || input.files!.isEmpty)) {
        cleanup();
        completer.complete(null);
      }
    });
  });

  input.click();
  return completer.future;
}
