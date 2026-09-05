import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/chat_controller.dart';
import 'core/brand.dart';
import 'core/constants.dart';
import 'data/local/database_helper.dart';
import 'data/repositories/chat_repository.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/crisis_detector.dart';
import 'services/settings_service.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Compose dependencies (manual dependency injection — OOADM modularity).
  final repo = ChatRepository(DatabaseHelper.instance);
  final ai = AiService();
  final crisis = CrisisDetector();
  final settings = SettingsService(DatabaseHelper.instance);
  final auth = AuthService(DatabaseHelper.instance);

  // Ensure the default admin account exists in the local database.
  await auth.seedDefaultAdmin();

  runApp(MindfulApp(
    controller: ChatController(repo, ai, crisis, settings),
    settings: settings,
    auth: auth,
    repo: repo,
  ));
}

class MindfulApp extends StatelessWidget {
  final ChatController controller;
  final SettingsService settings;
  final AuthService auth;
  final ChatRepository repo;

  const MindfulApp({
    super.key,
    required this.controller,
    required this.settings,
    required this.auth,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        Provider.value(value: settings),
        Provider.value(value: auth),
        Provider.value(value: repo),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Brand.seed,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
