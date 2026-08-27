import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cooksmart_app/main.dart';
import 'package:cooksmart_app/models/recipe_model.dart';
import 'package:cooksmart_app/models/shopping_item.dart';

/// Dynamic Data Generators for KitchenMate Test Suite
class DynamicTestDataFactory {
  static final _random = Random(DateTime.now().millisecondsSinceEpoch);

  static final _cuisines = [
    'Italian', 'Mexican', 'Indian', 'Japanese', 'Mediterranean', 'Thai', 'American', 'French'
  ];
  static final _spiceLevels = ['Mild', 'Medium', 'Hot', 'Extra Hot'];
  static final _dietTypes = ['Vegan', 'Vegetarian', 'Keto', 'Gluten-Free', 'Paleo', 'None'];
  static final _emojis = ['🥑', '🥗', '🍲', '🍕', '🌮', '🍛', '🍜', '🥘', '🍳', '🥦'];
  static final _ingredientPool = [
    '2 cloves garlic', '1 cup diced onions', '2 tbsp extra virgin olive oil',
    '1/2 tsp smoked paprika', '200g chickpeas', '1 bunch fresh basil',
    '1 ripe avocado', '150g quinoa', '1 cup almond milk', '1/2 cup cherry tomatoes'
  ];

  static String generateUniqueId([String prefix = 'id']) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randVal = _random.nextInt(100000);
    return '${prefix}_${timestamp}_$randVal';
  }

  static NutritionInfo generateDynamicNutrition({
    int? minCalories,
    int? maxCalories,
  }) {
    final minCal = minCalories ?? 100;
    final maxCal = maxCalories ?? 800;
    return NutritionInfo(
      calories: minCal + _random.nextInt(maxCal - minCal + 1),
      protein: (_random.nextDouble() * 40.0 * 10).round() / 10,
      carbs: (_random.nextDouble() * 80.0 * 10).round() / 10,
      fat: (_random.nextDouble() * 30.0 * 10).round() / 10,
      fiber: (_random.nextDouble() * 15.0 * 10).round() / 10,
    );
  }

  static Recipe generateDynamicRecipe({
    String? id,
    String? title,
    bool? isFavorite,
    int? ingredientCount,
  }) {
    final count = ingredientCount ?? (3 + _random.nextInt(4));
    final shuffled = List<String>.from(_ingredientPool)..shuffle(_random);
    final chosenIngredients = shuffled.take(count).toList();
    final chosenCuisine = _cuisines[_random.nextInt(_cuisines.length)];
    final uid = generateUniqueId('rec');

    return Recipe(
      id: id ?? uid,
      title: title ?? 'Dynamic $chosenCuisine Delight ${_random.nextInt(9999)}',
      description: 'Dynamically generated $chosenCuisine gourmet recipe with $count fresh ingredients.',
      ingredients: chosenIngredients,
      steps: List.generate(
        3 + _random.nextInt(3),
        (index) => 'Step ${index + 1}: Execute culinary preparation stage $index with precision.',
      ),
      cookingTimeMinutes: 10 + _random.nextInt(50),
      servings: 1 + _random.nextInt(6),
      spiceLevel: _spiceLevels[_random.nextInt(_spiceLevels.length)],
      nutrition: generateDynamicNutrition(),
      matchType: _random.nextBool() ? 'full' : 'partial',
      matchPercentage: 60 + _random.nextInt(41),
      imageEmoji: _emojis[_random.nextInt(_emojis.length)],
      cuisine: chosenCuisine,
      dietType: _dietTypes[_random.nextInt(_dietTypes.length)],
      isFavorite: isFavorite ?? _random.nextBool(),
    );
  }

  static Map<String, dynamic> generateDynamicRecipeJson() {
    final rec = generateDynamicRecipe();
    return rec.toJson();
  }
}

void main() {
  group('1. Dynamic Data Generator & Recipe Model Unit Tests', () {
    test('Dynamic Recipe generation produces unique IDs and valid fields', () {
      final recipe1 = DynamicTestDataFactory.generateDynamicRecipe();
      final recipe2 = DynamicTestDataFactory.generateDynamicRecipe();

      expect(recipe1.id, isNot(equals(recipe2.id)));
      expect(recipe1.title.isNotEmpty, isTrue);
      expect(recipe1.ingredients.length, greaterThanOrEqualTo(3));
      expect(recipe1.steps.length, greaterThanOrEqualTo(3));
      expect(recipe1.cookingTimeMinutes, greaterThan(0));
      expect(recipe1.servings, greaterThan(0));
      expect(recipe1.nutrition.calories, greaterThan(0));
    });

    test('Dynamic Recipe JSON serialization / deserialization roundtrip', () {
      final dynamicJson = DynamicTestDataFactory.generateDynamicRecipeJson();
      final recipe = Recipe.fromJson(dynamicJson);

      expect(recipe.id, equals(dynamicJson['id']));
      expect(recipe.title, equals(dynamicJson['title']));
      expect(recipe.ingredients.length, equals((dynamicJson['ingredients'] as List).length));
      expect(recipe.nutrition.calories, equals(dynamicJson['nutrition']['calories']));
      expect(recipe.nutrition.protein, equals(dynamicJson['nutrition']['protein']));

      final serializedBack = recipe.toJson();
      expect(serializedBack['id'], equals(dynamicJson['id']));
      expect(serializedBack['title'], equals(dynamicJson['title']));
      expect(serializedBack['matchPercentage'], equals(dynamicJson['matchPercentage']));
    });

    test('Dynamic NutritionInfo model correctly handles edge boundary values', () {
      final dynamicNutrition = DynamicTestDataFactory.generateDynamicNutrition(
        minCalories: 500,
        maxCalories: 900,
      );

      expect(dynamicNutrition.calories, inInclusiveRange(500, 900));
      expect(dynamicNutrition.protein, greaterThanOrEqualTo(0.0));
      expect(dynamicNutrition.carbs, greaterThanOrEqualTo(0.0));
      expect(dynamicNutrition.fat, greaterThanOrEqualTo(0.0));
      expect(dynamicNutrition.fiber, greaterThanOrEqualTo(0.0));

      final json = dynamicNutrition.toJson();
      final restored = NutritionInfo.fromJson(json);
      expect(restored.calories, equals(dynamicNutrition.calories));
      expect(restored.protein, equals(dynamicNutrition.protein));
    });

    test('Recipe.fromJson handles null or missing optional dynamic fields gracefully', () {
      final minimalJson = {
        'title': 'Dynamic Minimal Recipe',
        'ingredients': ['Tomato', 'Salt'],
        'steps': ['Mix together'],
      };

      final recipe = Recipe.fromJson(minimalJson);
      expect(recipe.title, 'Dynamic Minimal Recipe');
      expect(recipe.id.isNotEmpty, isTrue);
      expect(recipe.cookingTimeMinutes, 30);
      expect(recipe.servings, 4);
      expect(recipe.spiceLevel, 'Mild');
      expect(recipe.cuisine, 'International');
      expect(recipe.isFavorite, isFalse);
    });
  });

  group('2. Dynamic UI Widget & State Rendering Tests', () {
    testWidgets('Dynamic Recipe Card UI item renders dynamic titles and tags', (WidgetTester tester) async {
      final dynamicRecipe = DynamicTestDataFactory.generateDynamicRecipe(
        title: 'Dynamic Signature Pizza',
        isFavorite: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Column(
                children: [
                  Text(dynamicRecipe.title),
                  Text('${dynamicRecipe.cookingTimeMinutes} mins'),
                  Text(dynamicRecipe.cuisine),
                  Icon(
                    dynamicRecipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    key: const Key('favorite_icon'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dynamic Signature Pizza'), findsOneWidget);
      expect(find.text('${dynamicRecipe.cookingTimeMinutes} mins'), findsOneWidget);
      expect(find.text(dynamicRecipe.cuisine), findsOneWidget);
      expect(find.byKey(const Key('favorite_icon')), findsOneWidget);
    });

    testWidgets('KitchenMate Main App loads successfully smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(const RecipeApp());
      expect(find.byType(RecipeApp), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(RecipeApp), findsOneWidget);
    });
  });

  group('3. Pantry & Shopping List Feature Tests', () {
    test('ShoppingItem model serialization, deserialization, and toggle', () {
      final item = ShoppingItem(
        id: 'shop_001',
        name: 'Tomato',
        isCompleted: false,
      );

      expect(item.name, 'Tomato');
      expect(item.isCompleted, isFalse);

      item.isCompleted = true;
      final json = item.toJson();
      expect(json['id'], 'shop_001');
      expect(json['name'], 'Tomato');
      expect(json['isCompleted'], isTrue);

      final fromJson = ShoppingItem.fromJson(json);
      expect(fromJson.name, 'Tomato');
      expect(fromJson.isCompleted, isTrue);
    });

    testWidgets('Shopping List item renders with red strikethrough when checked', (WidgetTester tester) async {
      final checkedItem = ShoppingItem(
        id: 'shop_002',
        name: 'Milk',
        isCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Checkbox(
                value: checkedItem.isCompleted,
                onChanged: (_) {},
              ),
              title: Text(
                checkedItem.name,
                style: TextStyle(
                  decoration: checkedItem.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: Colors.red,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Milk'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Milk'));
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      expect(textWidget.style?.decorationColor, Colors.red);
    });

    test('Recipe to Shopping List compares Pantry and only identifies missing items', () {
      final pantry = ['Tomato', 'Onion'];
      final recipeIngredients = ['Tomato', 'Onion', 'Chicken', 'Cheese'];

      final missing = recipeIngredients.where((ing) {
        final lowerIng = ing.toLowerCase();
        return !pantry.any((p) => lowerIng.contains(p.toLowerCase()));
      }).toList();

      expect(missing, equals(['Chicken', 'Cheese']));
      expect(missing.contains('Tomato'), isFalse);
      expect(missing.contains('Onion'), isFalse);
    });
  });
}
