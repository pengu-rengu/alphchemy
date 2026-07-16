import "package:alphchemy_app/blocs/theme_bloc.dart";
import "package:alphchemy_app/env.dart";
import "package:alphchemy_app/router.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_web_plugins/url_strategy.dart";
import "package:forui/forui.dart";
import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";

final lightTheme = FThemes.neutral.light.desktop;
final darkTheme = FThemes.neutral.dark.desktop;
final lightMaterialTheme = lightTheme.toApproximateMaterialTheme();
final darkMaterialTheme = darkTheme.toApproximateMaterialTheme();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey
  );

  final supabaseClient = Supabase.instance.client;
  final docsHttpClient = http.Client();
  final router = createRouter(supabaseClient);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SupabaseClient>.value(value: supabaseClient),
        RepositoryProvider<http.Client>.value(value: docsHttpClient)
      ],
      child: BlocProvider<ThemeBloc>(
        create: (_) => ThemeBloc(),
        child: BlocBuilder<ThemeBloc, ThemeMode>(
          builder: (context, mode) {
            final isDark = mode == ThemeMode.dark;
            final theme = isDark ? darkTheme : lightTheme;
            return MaterialApp.router(
              theme: lightMaterialTheme,
              darkTheme: darkMaterialTheme,
              themeMode: mode,
              routerConfig: router,
              builder: (context, child) => FTheme(data: theme, child: child!)
            );
          }
        )
      )
    )
  );
}
