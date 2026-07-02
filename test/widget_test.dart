import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegoal_app/widgets/app_logo.dart';

void main() {
  testWidgets('App logo asset loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppLogo(size: 64)),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
