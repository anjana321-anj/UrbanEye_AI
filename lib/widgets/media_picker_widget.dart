import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// US-05: max 5 photos (<=5MB each) OR 1 video (<=30s).
class MediaPickerWidget extends StatelessWidget {
  final List<File> photos;
  final File? video;
  final void Function(List<File> photos, File? video) onChanged;
  const MediaPickerWidget({super.key, required this.photos, required this.video, required this.onChanged});

  Future<void> _pick(BuildContext ctx, ImageSource src, bool isVideo) async {
    final p = ImagePicker();
    final msg = ScaffoldMessenger.of(ctx);
    if (isVideo) {
      if (photos.isNotEmpty) {
        msg.showSnackBar(const SnackBar(content: Text('Choose either photos or one video')));
        return;
      }
      final x = await p.pickVideo(source: src, maxDuration: const Duration(seconds: 30));
      if (x != null) onChanged([], File(x.path));
    } else {
      if (video != null) {
        msg.showSnackBar(const SnackBar(content: Text('Choose either photos or one video')));
        return;
      }
      if (photos.length >= 5) {
        msg.showSnackBar(const SnackBar(content: Text('Maximum 5 photos')));
        return;
      }
      final x = await p.pickImage(source: src, imageQuality: 100);
      if (x == null) return;
      final f = File(x.path);
      if (await f.length() > 5 * 1024 * 1024) {
        msg.showSnackBar(const SnackBar(content: Text('Photo exceeds 5 MB')));
        return;
      }
      onChanged([...photos, f], null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.camera, false), icon: const Icon(Icons.camera_alt), label: const Text('Camera')),
          OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.gallery, false), icon: const Icon(Icons.photo), label: const Text('Gallery')),
          OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.camera, true), icon: const Icon(Icons.videocam), label: const Text('Video')),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 80, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < photos.length; i++)
            Stack(children: [
              Padding(padding: const EdgeInsets.only(right: 6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(photos[i], width: 80, height: 80, fit: BoxFit.cover))),
              Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => onChanged([...photos]..removeAt(i), null), child: const CircleAvatar(radius: 10, child: Icon(Icons.close, size: 12)))),
            ]),
          if (video != null) Chip(avatar: const Icon(Icons.videocam), label: const Text('1 video'), onDeleted: () => onChanged([], null)),
        ])),
      ]);
}
