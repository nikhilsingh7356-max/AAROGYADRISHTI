/// Application composition root: builds the API client, repositories,
/// providers and the root router.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/profile_repository.dart';

enum AppThemePreference { system, light, dark }

class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  AppThemePreference _preference = AppThemePreference.system;
  AppThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.system => ThemeMode.system,
      };

  Future<void> _load() async {
    final raw = await StorageService.instance.getString(AppConstants.keyThemeMode);
    if (raw == null) return;
    for (final pref in AppThemePreference.values) {
      if (pref.name == raw && pref != _preference) {
        _preference = pref;
        notifyListeners();
        break;
      }
    }
  }

  Future<void> setPreference(AppThemePreference pref) async {
    if (pref == _preference) return;
    _preference = pref;
    notifyListeners();
    await StorageService.instance.setString(AppConstants.keyThemeMode, pref.name);
  }
}

/// Singleton data-layer container exposed through the widget tree.
///
/// All repositories share ONE `ApiClient` so a session token set after login
/// is automatically available to every repository.
class AppServices {
  AppServices._() : api = ApiClient(baseUrl: AppConstants.apiBaseUrl) {
    authRepository = AuthRepository(api);
    profileRepository = ProfileRepository(api);
    // Persist refreshed tokens so a restored session never runs on a stale
    // refresh token after the access token expires.
    api.onTokensRefreshed = (access, refresh) {
      StorageService.instance.saveTokens(access: access, refresh: refresh);
    };
  }

  final ApiClient api;
  late final AuthRepository authRepository;
  late final ProfileRepository profileRepository;

  static final AppServices _instance = AppServices._();
  static AppServices get instance => _instance;
}

class AarogyaDrishtiApp extends StatefulWidget {
  const AarogyaDrishtiApp({super.key});

  @override
  State<AarogyaDrishtiApp> createState() => _AarogyaDrishtiAppState();
}

class _AarogyaDrishtiAppState extends State<AarogyaDrishtiApp> {
  late final AuthProvider _auth;
  late final ThemeController _theme;

  @override
  void initState() {
    super.initState();
    final svc = AppServices.instance;
    _auth = AuthProvider(
      svc.authRepository,
      storage: StorageService.instance,
    );
    _theme = ThemeController();
  }

  @override
  void dispose() {
    _theme.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<ThemeController>.value(value: _theme),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeCtrl, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeCtrl.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
