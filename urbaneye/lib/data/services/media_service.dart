import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';

/// Picks/captures media and returns compressed [Evidence]. Images are
/// downscaled to 1600px @ 75% JPEG quality on-device before upload, which
/// keeps reports fast on mobile networks.
class MediaService {
  MediaService._();
  static final _picker = ImagePicker();

  static Evidence _wrap(Uint8List bytes, EvidenceKind kind) => Evidence(
        id: 'ev-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        bytes: bytes,
        capturedAt: DateTime.now(),
      );

  static Future<Evidence?> fromXFile(XFile? f, {EvidenceKind kind = EvidenceKind.photo}) async {
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    return _wrap(bytes, kind);
  }

  static Future<Evidence?> captureWithSystemCamera() async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
    return fromXFile(f);
  }

  static Future<List<Evidence>> pickPhotos({int max = 5}) async {
    if (max <= 0) return [];
    if (max == 1) {
      // pickMultiImage requires a limit of at least 2.
      final single = await pickSinglePhoto();
      return single == null ? [] : [single];
    }
    final files = await _picker.pickMultiImage(imageQuality: 75, maxWidth: 1600, limit: max);
    final out = <Evidence>[];
    for (final f in files.take(max)) {
      final e = await fromXFile(f);
      if (e != null) out.add(e);
    }
    return out;
  }

  static Future<Evidence?> pickSinglePhoto({bool camera = false}) async {
    final f = await _picker.pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, imageQuality: 75, maxWidth: 1600);
    return fromXFile(f);
  }

  static Future<Evidence?> recordVideo({bool camera = true}) async {
    final f = await _picker.pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    return fromXFile(f, kind: EvidenceKind.video);
  }
}
