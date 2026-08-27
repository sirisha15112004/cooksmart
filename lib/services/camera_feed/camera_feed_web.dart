import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'camera_feed_interface.dart';

class WebCameraFeed implements LiveCameraFeed {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  Timer? _frameTimer;
  late final String _viewType;
  bool _isStreaming = false;

  @override
  bool get isStreaming => _isStreaming;

  WebCameraFeed() {
    _viewType = 'kitchenmate-webcam-${DateTime.now().microsecondsSinceEpoch}';
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement!,
    );
  }

  @override
  Widget buildPreview() {
    return HtmlElementView(viewType: _viewType);
  }

  @override
  Future<bool> startCamera({required Function(Uint8List frameBytes) onFrameCaptured}) async {
    try {
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      if (_mediaStream != null && _videoElement != null) {
        _videoElement!.srcObject = _mediaStream;
        _isStreaming = true;

        // Sample frame every 750ms for live ingredient detection
        _frameTimer?.cancel();
        _frameTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
          _captureCurrentFrame(onFrameCaptured);
        });

        return true;
      }
    } catch (e) {
      debugPrint('Web camera getUserMedia error: $e');
    }
    return false;
  }

  void _captureCurrentFrame(Function(Uint8List frameBytes) onFrameCaptured) {
    if (_videoElement == null || !_isStreaming) return;
    final w = _videoElement!.videoWidth;
    final h = _videoElement!.videoHeight;
    if (w <= 10 || h <= 10) return;

    try {
      final canvas = html.CanvasElement(width: w, height: h);
      canvas.context2D.drawImage(_videoElement!, 0, 0);
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      final base64String = dataUrl.split(',').last;
      final bytes = base64Decode(base64String);
      onFrameCaptured(bytes);
    } catch (e) {
      debugPrint('Live frame capture note: $e');
    }
  }

  @override
  void stopCamera() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _isStreaming = false;
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
  }
}

LiveCameraFeed getLiveCameraFeed() => WebCameraFeed();
