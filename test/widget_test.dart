import 'package:ai_voice_translator/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads voice translator home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VoiceTranslatorApp());
    await tester.pump();

    expect(find.text('声译 AI'), findsOneWidget);
    expect(find.textContaining('视频听译'), findsWidgets);
    expect(find.textContaining('开始视频听译'), findsWidgets);
  });
}
