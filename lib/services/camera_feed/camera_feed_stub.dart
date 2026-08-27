import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'camera_feed_interface.dart';

class StubCameraFeed implements LiveCameraFeed {
  @override
  bool get isStreaming => false;

  @override
  Widget buildPreview() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Live Camera is active on Web/Device',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Future<bool> startCamera({required Function(Uint8List frameBytes) onFrameCaptured}) async {
    return true;
  }

  @override
  void stopCamera() {}
}

LiveCameraFeed getLiveCameraFeed() => StubCameraFeed();
