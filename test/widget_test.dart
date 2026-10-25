import 'package:flutter_test/flutter_test.dart';
import 'package:driveplus_flutter/main.dart';

void main() {
  testWidgets('DrivePlusApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DrivePlusApp());
    expect(find.text('DRIVEPLUS'), findsWidgets);
  });
}
