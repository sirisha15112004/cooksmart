import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../models/recipe_model.dart';

class RecipeService {
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'YOUR_GROQ_API_KEY_HERE',
  );
  static const String _baseUrl =
      "https://api.groq.com/openai/v1/chat/completions";
  static const String _visionModel =
      "meta-llama/llama-4-scout-17b-16e-instruct";
  static const String _textModel = "llama-3.1-8b-instant";

  /// Scan ingredients from image using Groq Vision API
  Future<List<String>> scanIngredientsFromImage(File imageFile) async {
    final fileSize = await imageFile.length();
    if (fileSize > 4 * 1024 * 1024) {
      throw Exception("Image too large. Please use an image under 4MB.");
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a culinary AI assistant. When given an image of food ingredients, identify all visible ingredients and return them as a JSON array of strings. Return ONLY valid JSON, no other text. Example: ["tomatoes", "onions", "garlic"]'
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Identify all food ingredients visible in this image. Return only a JSON array of ingredient names, nothing else.'
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$base64Image'}
              }
            ]
          }
        ],
        'temperature': 0.3,
        'max_completion_tokens': 512,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final clean =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = jsonDecode(clean);
      return parsed.cast<String>();
    }
    throw Exception('Failed to scan image: ${response.statusCode}');
  }

  /// Get recipes based on ingredients using Groq text API
  Future<Map<String, List<Recipe>>> getRecipes({
    required List<String> ingredients,
    required int servings,
    required String spiceLevel,
    String? dietType,
  }) async {
    final dietNote = (dietType != null && dietType != 'None')
        ? 'Diet requirement: $dietType — ALL recipes MUST strictly follow this diet.'
        : '';

    final dietConstraints = _getDietConstraints(dietType);

    final prompt = '''
Given these ingredients: ${ingredients.join(', ')}
Servings: $servings
Spice level: $spiceLevel
$dietNote
$dietConstraints

Generate recipes in this EXACT JSON format. Return ONLY valid JSON, nothing else:
{
  "fullMatch": [
    {
      "id": "1",
      "title": "Recipe Name",
      "description": "Brief appetizing description",
      "ingredients": ["ingredient 1 with quantity", "ingredient 2 with quantity"],
      "steps": ["Step 1 description", "Step 2 description", "Step 3 description"],
      "cookingTimeMinutes": 30,
      "servings": $servings,
      "spiceLevel": "$spiceLevel",
      "nutrition": {"calories": 350, "protein": 20.5, "carbs": 45.0, "fat": 12.0, "fiber": 5.0},
      "matchType": "full",
      "matchPercentage": 100,
      "imageEmoji": "🍲",
      "cuisine": "Indian",
      "dietType": "${dietType ?? 'None'}"
    },
    {
      "id": "2",
      "title": "Second Recipe Name",
      "description": "Brief appetizing description",
      "ingredients": ["ingredient 1 with quantity", "ingredient 2 with quantity"],
      "steps": ["Step 1", "Step 2", "Step 3"],
      "cookingTimeMinutes": 25,
      "servings": $servings,
      "spiceLevel": "$spiceLevel",
      "nutrition": {"calories": 300, "protein": 18.0, "carbs": 40.0, "fat": 10.0, "fiber": 4.0},
      "matchType": "full",
      "matchPercentage": 100,
      "imageEmoji": "🥘",
      "cuisine": "Mediterranean",
      "dietType": "${dietType ?? 'None'}"
    }
  ],
  "partialMatch": [
    {
      "id": "3",
      "title": "Partial Recipe Name",
      "description": "Brief description",
      "ingredients": ["ingredient 1", "ingredient 2", "ingredient 3 (needed extra)"],
      "steps": ["Step 1", "Step 2", "Step 3"],
      "cookingTimeMinutes": 25,
      "servings": $servings,
      "spiceLevel": "$spiceLevel",
      "nutrition": {"calories": 280, "protein": 15.0, "carbs": 38.0, "fat": 8.0, "fiber": 4.0},
      "matchType": "partial",
      "matchPercentage": 75,
      "imageEmoji": "🥗",
      "cuisine": "Fusion",
      "dietType": "${dietType ?? 'None'}"
    },
    {
      "id": "4",
      "title": "Second Partial Recipe",
      "description": "Brief description",
      "ingredients": ["ingredient 1", "ingredient 2"],
      "steps": ["Step 1", "Step 2"],
      "cookingTimeMinutes": 20,
      "servings": $servings,
      "spiceLevel": "$spiceLevel",
      "nutrition": {"calories": 250, "protein": 12.0, "carbs": 35.0, "fat": 7.0, "fiber": 3.0},
      "matchType": "partial",
      "matchPercentage": 65,
      "imageEmoji": "🍜",
      "cuisine": "Asian",
      "dietType": "${dietType ?? 'None'}"
    }
  ],
  "alternative": [
    {
      "id": "5",
      "title": "Alternative Recipe",
      "description": "Brief description",
      "ingredients": ["ingredient 1", "ingredient 2"],
      "steps": ["Step 1", "Step 2"],
      "cookingTimeMinutes": 20,
      "servings": $servings,
      "spiceLevel": "$spiceLevel",
      "nutrition": {"calories": 200, "protein": 10.0, "carbs": 30.0, "fat": 5.0, "fiber": 3.0},
      "matchType": "alternative",
      "matchPercentage": 50,
      "imageEmoji": "🥙",
      "cuisine": "International",
      "dietType": "${dietType ?? 'None'}"
    }
  ]
}

Make recipes realistic, delicious, and appropriate for spice level "$spiceLevel". Provide detailed steps.''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _textModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a professional chef AI. Return only valid JSON when asked for recipes. No markdown, no explanation, just pure JSON.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
        'max_tokens': 3000,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final clean =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> parsed = jsonDecode(clean);

      return {
        'fullMatch': (parsed['fullMatch'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList(),
        'partialMatch': (parsed['partialMatch'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList(),
        'alternative': (parsed['alternative'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList(),
      };
    }
    throw Exception('Failed to get recipes: ${response.statusCode}');
  }

  String _getDietConstraints(String? dietType) {
    switch (dietType) {
      case 'Vegetarian':
        return 'STRICT: No meat, no chicken, no fish, no seafood. Eggs and dairy are allowed.';
      case 'Vegan':
        return 'STRICT: No animal products at all — no meat, no fish, no eggs, no dairy, no honey. Only plant-based ingredients.';
      case 'High-Protein':
        return 'Each recipe must have at least 25g protein per serving. Use protein-rich ingredients like chicken, eggs, paneer, lentils, beans, tofu, or Greek yogurt. Reflect this in the nutrition values.';
      case 'Diabetic-Friendly':
        return 'STRICT: Low glycemic index ingredients only. No sugar, no white rice, no white bread, no refined carbs. Use whole grains, vegetables, lean protein. Keep carbs under 40g per serving. Reflect this in the nutrition values.';
      case 'Weight-Loss':
        return 'Keep calories under 300 per serving. Low fat, high fiber, high volume ingredients. No deep frying. Prefer grilling, steaming, or boiling. Reflect this in the nutrition values.';
      default:
        return '';
    }
  }
}
