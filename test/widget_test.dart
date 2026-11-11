import 'package:flutter/material.dart';
import 'package:dhker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('يعرض التطبيق وجهات التنقل الرئيسية', (tester) async {
    await tester.pumpWidget(const DhikrApp());
    // Allow the dashboard's staggered flutter_animate effects to finish.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('المواقيت'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);
    expect(find.text('الأذان'), findsOneWidget);

    // Unmount the dashboard so its clock timer is disposed before teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
