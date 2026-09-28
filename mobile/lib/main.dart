import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_store.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/notification_service.dart';
import 'services/call_overlay_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp warning: $e');
  }

  try {
    await NotificationService.initialize();
    await NotificationService.initFirebaseMessaging();
  } catch (e) {
    debugPrint('NotificationService init warning: $e');
  }

  // ── Foreground call: show overlay banner on top of current screen ──────
  NotificationService.onCallReceived = (callData) {
    // Store in notification center
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Provider.of<NotificationStore>(ctx, listen: false).addFromData({
        ...callData,
        'type': 'incoming_call',
        'title': '📞 Incoming Call: ${callData['callerName'] ?? 'Caller'}',
        'body': '${callData['callerRole'] ?? 'User'} is calling you',
      });
      CallOverlayService.showIncomingCallOverlay(
        context: ctx,
        callId: callData['callId'] ?? '',
        callerName: callData['callerName'] ?? 'Unknown Caller',
        callerRole: callData['callerRole'] ?? 'Caller',
        callerUserId: callData['callerId'],
        liveKitUrl: callData['liveKitUrl'],
        calleeToken: callData['calleeToken'],
      );
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: callData['callId'] ?? '',
            callerName: callData['callerName'] ?? 'Unknown Caller',
            callerRole: callData['callerRole'] ?? 'Caller',
            callerUserId: callData['callerId'],
            liveKitUrl: callData['liveKitUrl'],
            calleeToken: callData['calleeToken'],
          ),
        ),
      );
    }
  };

  // ── Store all other task updates in notification center ────────────
  NotificationService.onTaskUpdated = (taskData) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Provider.of<NotificationStore>(ctx, listen: false).addFromData(taskData);
    }
  };

  // ── Background → Foreground: user taps call notification ──────────────
  // Handles when app was in background/terminated and user taps the
  // incoming call notification to bring the app to foreground.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    if (type == 'incoming_call') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: data['callId'] ?? '',
            callerName: data['callerName'] ?? 'Unknown Caller',
            callerRole: data['callerRole'] ?? 'Caller',
            callerUserId: data['callerId'],
            liveKitUrl: data['liveKitUrl'],
            calleeToken: data['calleeToken'],
          ),
        ),
      );
    }
  });

  // ── Terminated state: app opened via notification tap ─────────────────
  // Handles when app was fully terminated and user taps the notification.
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final data = initialMessage.data;
      final type = data['type']?.toString();
      if (type == 'incoming_call') {
        // Defer navigation until navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callId: data['callId'] ?? '',
                callerName: data['callerName'] ?? 'Unknown Caller',
                callerRole: data['callerRole'] ?? 'Caller',
                callerUserId: data['callerId'],
                liveKitUrl: data['liveKitUrl'],
                calleeToken: data['calleeToken'],
              ),
            ),
          );
        });
      }
    }
  } catch (_) {}

  final notificationStore = NotificationStore()..seedDemoNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: notificationStore),
      ],
      child: const ShopConnectorApp(),
    ),
  );
}

class ShopConnectorApp extends StatelessWidget {
  const ShopConnectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'LocalConnect',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.mode,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isAuthenticated) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
