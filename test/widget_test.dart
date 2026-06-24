import 'package:flutter_test/flutter_test.dart';

import 'package:piece_rate_wage/main.dart';

void main() {
  testWidgets('App should display title', (WidgetTester tester) async {
    await tester.pumpWidget(const PieceRateWageApp());

    // Verify the app title is present
    expect(find.text('包袋厂计件工资管理系统'), findsWidgets);
  });
}
