import 'package:flutter_test/flutter_test.dart';
import 'package:rubezh/main.dart';

void main() {
  testWidgets('приложение запускается', (tester) async {
    await tester.pumpWidget(const RubezhApp(autoInit: false));
    expect(find.text('РУБЕЖ'), findsOneWidget);
  });
}
