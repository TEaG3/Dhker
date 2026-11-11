import 'package:dhker/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('يعرض التطبيق وجهات التنقل الرئيسية', (tester) async {
    await tester.pumpWidget(const DhikrApp(enableClock: false, testMode: true));
    await tester.pump();

    // The first destination also appears in the navigation bar and placeholder.
    expect(find.text('المواقيت'), findsAtLeastNWidgets(1));
    expect(find.text('القرآن'), findsAtLeastNWidgets(1));
    expect(find.text('الأذكار'), findsAtLeastNWidgets(1));
    expect(find.text('الأذان'), findsAtLeastNWidgets(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
