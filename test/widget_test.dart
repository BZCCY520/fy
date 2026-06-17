import 'package:emby_media_player/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads Emby player app', (tester) async {
    await tester.pumpWidget(const EmbyPlayerApp());
    await tester.pumpAndSettle();

    expect(find.text('Emby 媒体播放器'), findsWidgets);
  });
}
