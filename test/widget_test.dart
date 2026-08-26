import 'package:flutter_test/flutter_test.dart';
import 'package:cooksmart_app/main.dart';

void main() {
  testWidgets('App loads successfully smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RecipeApp());
    expect(find.byType(RecipeApp), findsOneWidget);
  });
}

