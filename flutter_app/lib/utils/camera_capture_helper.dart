import 'dart:typed_data';
import 'camera_capture_helper_stub.dart'
    if (dart.library.html) 'camera_capture_helper_web.dart' as impl;

class CapturedPhoto {
  final String name;
  final Uint8List bytes;

  const CapturedPhoto({required this.name, required this.bytes});
}

Future<CapturedPhoto?> capturePhotoFromCamera() {
  return impl.capturePhotoFromCamera();
}
