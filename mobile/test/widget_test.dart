import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shop_connector_app/providers/auth_provider.dart';
import 'package:shop_connector_app/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ShopConnector Login Screen test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Set larger test screen to prevent keyboard/small screen scroll constraints
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('ShopConnector'), findsOneWidget);
    expect(find.text('Fast Login (PIN)'), findsOneWidget);
  });
}
