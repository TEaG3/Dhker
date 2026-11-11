import 'package:dhker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('يعرض التطبيق وجهات التنقل الرئيسية', (tester) async {
    await tester.pumpWidget(const DhikrApp());
    await tester.pump();

    expect(find.text('المواقيت'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);
    expect(find.text('الأذان'), findsOneWidget);
  });
}
