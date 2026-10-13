import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';

/// Picks up to [limit] photos from the gallery (empty when cancelled).
typedef PostImagePicker = Future<List<NewPostImage>> Function({
  required int limit,
});

Future<List<NewPostImage>> _pickFromGallery({required int limit}) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (limit <= 1) {
    final one = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    files = one == null ? const [] : [one];
  } else {
    files = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      limit: limit,
    );
  }
  return [
    for (final f in files)
      NewPostImage(name: f.name, bytes: await f.readAsBytes()),
  ];
}

/// The device photo picker; replaced in tests.
final postImagePickerProvider = Provider<PostImagePicker>(
  (ref) => _pickFromGallery,
);

/// Picks one PDF (null when cancelled).
typedef PostPdfPicker = Future<PostAttachment?> Function();

Future<PostAttachment?> _pickPdf() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: true,
  );
  final files = result?.files ?? const <PlatformFile>[];
  final file = files.isEmpty ? null : files.first;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return PostAttachment(
    name: file.name,
    sizeBytes: bytes.lengthInBytes,
    bytes: bytes,
  );
}

/// The device PDF picker; replaced in tests.
final postPdfPickerProvider = Provider<PostPdfPicker>((ref) => _pickPdf);
