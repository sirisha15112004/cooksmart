import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ChatService {
  static const String _groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'YOUR_GROQ_API_KEY_HERE',
  );

  static const List<String> _apiKeys = [
    _groqApiKey,
  ];

  static const String _baseUrl =
      "https://api.groq.com/openai/v1/chat/completions";

  // Use vision-capable model for image analysis
  static const String _visionModel =
      "meta-llama/llama-4-scout-17b-16e-instruct";
  static const String _textModel = "llama-3.1-8b-instant";

  /// Send either text-only message or image-only message
  Future<String> sendMessage({String? message, File? imageFile}) async {
    if (message == null && imageFile == null) {
      return "Please provide either a text message or an image for analysis.";
    }

    for (int i = 0; i < _apiKeys.length; i++) {
      try {
        if (imageFile != null) {
          return await _sendImageOnlyRequest(imageFile, _apiKeys[i], message);
        } else {
          return await _sendTextOnlyRequest(message!, _apiKeys[i]);
        }
      } catch (e) {
        debugPrint('Exception with API key ${i + 1}: $e');
        continue;
      }
    }

    return "I'm experiencing high demand right now. Please try again in a few moments!";
  }

  Future<String> _sendTextOnlyRequest(String message, String apiKey) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _textModel,
        'messages': [
          {
            'role': 'system',
            'content':
                '''You are GREEN AI, an expert agricultural assistant specializing in sustainable farming practices, crop management, and modern agriculture techniques.'''
          },
          {'role': 'user', 'content': message}
        ],
        'temperature': 0.7,
        'max_tokens': 1024,
        'top_p': 0.9,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        return data['choices'][0]['message']['content'] ?? 'No response received.';
      }
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded');
    } else {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }

    throw Exception('No valid response received');
  }

  Future<String> _sendImageOnlyRequest(
      File imageFile, String apiKey, String? additionalText) async {
    try {
      final fileSize = await imageFile.length();
      if (fileSize > 4 * 1024 * 1024) {
        return "Image file is too large. Please use an image smaller than 4MB.";
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

      String analysisPrompt =
          '''Analyze this agricultural image and provide expert advice.
${additionalText != null ? 'Additional context: $additionalText' : ''}
Please provide practical, specific guidance that a farmer can implement immediately.''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _visionModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are GREEN AI, an expert agricultural vision assistant.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': analysisPrompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'temperature': 0.7,
          'max_completion_tokens': 1024,
          'top_p': 0.9,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ?? 'No response received.';
        }
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded');
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }

      throw Exception('No valid response received');
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }
}
