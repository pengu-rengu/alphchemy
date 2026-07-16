import "dart:async";

import "package:alphchemy_app/pages/experiments_page.dart";
import "package:alphchemy_app/pages/notebooks_page.dart";
import "package:alphchemy_app/pages/reference_page.dart";
import "package:alphchemy_app/pages/settings_page.dart";
import "package:alphchemy_app/pages/signin_page.dart";
import "package:alphchemy_app/pages/signup_page.dart";
import "package:alphchemy_app/pages/reset_password_page.dart";
import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(SupabaseClient client) {

  return GoRouter(
    initialLocation: "/signin",
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final location = state.matchedLocation;
      final atAuth = location == "/signin" || location == "/signup";

      if (!loggedIn && !atAuth) return "/signin";
      if (loggedIn && atAuth) return "/experiments";
      return null;
    },
    routes: [
      GoRoute(path: "/signin", pageBuilder: (context, state) => const NoTransitionPage(child: SignInPage())),
      GoRoute(path: "/signup", pageBuilder: (context, state) => const NoTransitionPage(child: SignUpPage())),
      GoRoute(path: "/reset-password", pageBuilder: (context, state) => const NoTransitionPage(child: ResetPasswordPage())),
      GoRoute(path: "/experiments", pageBuilder: (context, state) => const NoTransitionPage(child: ExperimentsPage())),
      GoRoute(path: "/analysis", pageBuilder: (context, state) => const NoTransitionPage(child: NotebooksPage())),
      GoRoute(path: "/reference", pageBuilder: (context, state) => const NoTransitionPage(child: ReferencePage())),
      GoRoute(path: "/settings", pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()))
    ]
  );
}
