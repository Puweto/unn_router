import 'package:flutter_test/flutter_test.dart';
import 'package:unn_route_navigator/main.dart';

void main() {
  testWidgets('shows the splash, then the name screen when no user is saved', (tester) async {
    await tester.pumpWidget(const NavigatorApp());

    // Splash screen first
    expect(find.text('Campus shuttles & bus stops, Nsukka'), findsOneWidget);

    // After the splash delay the user is asked for their name only
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Welcome! What is your name?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Director of Transport sign in'), findsOneWidget);
  });
}
