import 'dart:typed_data';
import 'package:flutter/material.dart';

abstract class LiveCameraFeed {
  bool get isStreaming;
  Widget buildPreview();
  Future<bool> startCamera({required Function(Uint8List frameBytes) onFrameCaptured});
  void stopCamera();
}
