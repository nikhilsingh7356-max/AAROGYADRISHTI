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

  @override
  void initState() {
    super.initState();
    final svc = AppServices.instance;
    _auth = AuthProvider(
      svc.authRepository,
      storage: StorageService.instance,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: _auth,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}