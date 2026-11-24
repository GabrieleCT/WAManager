import 'dart:typed_data';
import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as impl;

Future<void> saveFileBytes(Uint8List bytes, String filename) async {
  await impl.saveFileBytes(bytes, filename);
}
