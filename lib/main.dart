import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/transcription/presentation/transcription_view_model.dart';
import 'features/transcription/presentation/transcription_page.dart';
import 'core/theme/app_theme.dart';

import 'features/settings/data/native_settings_repository.dart';
import 'features/settings/domain/settings_repository.dart';
import 'core/services/background_service_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Background Service
  await BackgroundServiceManager.initialize();

  // Fix Android Nav Bar overlap (Edge-to-Edge)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SettingsRepository>(create: (_) => NativeSettingsRepository()),
        ChangeNotifierProvider(create: (_) => TranscriptionViewModel()),
      ],
      child: MaterialApp(
        title: 'Recall.Me',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const TranscriptionPage(),
      ),
    );
  }
}
