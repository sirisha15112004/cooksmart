class Recipe {
  final String id;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final int cookingTimeMinutes;
  final int servings;
  final String spiceLevel;
  final NutritionInfo nutrition;
  final String matchType;
  final int matchPercentage;
  final String? imageEmoji;
  final String cuisine;
  final String? dietType;
  bool isFavorite;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.cookingTimeMinutes,
    required this.servings,
    required this.spiceLevel,
    required this.nutrition,
    required this.matchType,
    required this.matchPercentage,
    this.imageEmoji,
    required this.cuisine,
    this.dietType,
    this.isFavorite = false,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      cookingTimeMinutes: (json['cookingTimeMinutes'] ?? 30).toInt(),
      servings: (json['servings'] ?? 4).toInt(),
      spiceLevel: json['spiceLevel'] ?? 'Mild',
      nutrition: NutritionInfo.fromJson(json['nutrition'] ?? {}),
      matchType: json['matchType'] ?? 'full',
      matchPercentage: (json['matchPercentage'] ?? 100).toInt(),
      imageEmoji: json['imageEmoji'],
      cuisine: json['cuisine'] ?? 'International',
      dietType: json['dietType'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'ingredients': ingredients,
    'steps': steps,
    'cookingTimeMinutes': cookingTimeMinutes,
    'servings': servings,
    'spiceLevel': spiceLevel,
    'nutrition': nutrition.toJson(),
    'matchType': matchType,
    'matchPercentage': matchPercentage,
    'imageEmoji': imageEmoji,
    'cuisine': cuisine,
    'dietType': dietType,
    'isFavorite': isFavorite,
  };
}

class NutritionInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      fiber: (json['fiber'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
  };
}
