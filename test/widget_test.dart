import 'package:ai_subtitle_translator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads AI subtitle app', (tester) async {
    await tester.pumpWidget(const AISubtitleApp());
    await tester.pumpAndSettle();

    expect(find.text('AI 字幕'), findsWidgets);
  });
}
