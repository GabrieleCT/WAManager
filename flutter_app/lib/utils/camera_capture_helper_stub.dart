import 'package:file_picker/file_picker.dart';
import 'camera_capture_helper.dart';

Future<CapturedPhoto?> capturePhotoFromCamera() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return CapturedPhoto(name: file.name, bytes: bytes);
}
