import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_notifier.dart';
import 'package:flutter/material.dart';

import 'pages/splash_screen.dart';
import 'pages/onboarding_page.dart';
import 'pages/account_selection.dart';
import 'pages/complete_profile_page.dart';
import 'pages/cliente/client_auth.dart';
import 'pages/cliente/client_home.dart';
import 'pages/cliente/client_profile.dart';
import 'pages/cliente/client_createorder.dart';
import 'pages/cliente/client_orderstate.dart';
import 'pages/cliente/client_support.dart';
import 'pages/cliente/client_ordersummary.dart';
import 'pages/cliente/client_history.dart';
import 'pages/entregador/delivery_auth.dart';
import 'pages/entregador/delivery_home.dart';
import 'pages/entregador/delivery_profile.dart';
import 'pages/entregador/delivery_history.dart';
import 'pages/entregador/delivery_orderslist.dart';
import 'pages/entregador/delivery_orderstate.dart';
import 'pages/entregador/delivery_support.dart';
import 'pages/entregador/delivery_ordersummary.dart';

final AuthNotifier authNotifier = AuthNotifier();

String? userRole;

Future<void> initializeUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  userRole = prefs.getString('user_role');
}

void handleBackButtonBehavior() {
  // Adicionar listener para o evento de botão de volta do sistema
  SystemChannels.platform.setMethodCallHandler((call) async {
    if (call.method == 'SystemNavigator.pop') {
      // Permitir que o comportamento padrão seja executado
      return null;
    }
    return null;
  });
}

CustomTransitionPage buildTransitionPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: <Widget>[
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(1.0, 0.0),
            ).animate(animation),
            child: const SizedBox.shrink(), // Placeholder para a página atual
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child, // Nova página
          ),
        ],
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  refreshListenable: authNotifier,
  routerNeglect: false,
  navigatorKey: GlobalKey<NavigatorState>(),
  errorBuilder: (context, state) => const Scaffold(
    body: Center(child: Text('An error occurred')),
  ),
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final location = state.uri.toString();

    final isOnAuthPage = location == '/cliente/client_auth' ||
        location == '/entregador/delivery_auth';
    final isOnAccountSelection = location == '/account_selection';
    final isOnSplash = location == '/splash';

    // Retrieve userRole from SharedPreferences
    String? userRole;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      userRole = prefs.getString('user_role');
    }

    if (user == null) {
      if (!isOnAuthPage && !isOnAccountSelection) {
        return '/account_selection';
      }
      return null;
    }

    if (isOnAuthPage || isOnAccountSelection || isOnSplash) {
      if (userRole == 'cliente') return '/cliente/client_home';
      if (userRole == 'entregador') return '/entregador/delivery_home';
    }

    return null;
  },
  routes: [
    GoRoute(
        path: '/verifica',
        redirect: (context, state) {
          final user = FirebaseAuth.instance.currentUser;

          if (user == null) return '/account_selection';

          if (userRole == 'cliente') return '/cliente/client_home';
          if (userRole == 'entregador') return '/entregador/delivery_home';

          return '/account_selection';
        },
        pageBuilder: (context, state) => buildTransitionPage(
            const SizedBox.shrink(), // vazio
            state)),
    GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) =>
            buildTransitionPage(const SplashScreen(), state)),
    GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) =>
            buildTransitionPage(const OnboardingPage(), state)),
    GoRoute(
        path: '/account_selection',
        name: 'account_selection',
        pageBuilder: (context, state) =>
            buildTransitionPage(const AccountSelectionPage(), state)),
    GoRoute(
      path: '/complete_profile',
      builder: (context, state) {
        final targetRole =
            (state.extra as Map<String, dynamic>)['targetRole'] as String;
        return CompleteProfilePage(targetRole: targetRole);
      },
    ),
    GoRoute(
        path: '/cliente/client_auth',
        name: 'client_auth',
        pageBuilder: (context, state) =>
            buildTransitionPage(const ClientAuthPage(), state)),
    GoRoute(
        path: '/cliente/client_home',
        name: 'client_home',
        pageBuilder: (context, state) =>
            buildTransitionPage(const ClientHomePage(), state)),
    GoRoute(
        path: '/cliente/client_profile',
        name: 'client_profile',
        pageBuilder: (context, state) =>
            buildTransitionPage(const ClientProfilePage(), state)),
    GoRoute(
        path: '/cliente/client_createorder',
        name: 'client_createorder',
        pageBuilder: (context, state) =>
            buildTransitionPage(const ClientCreateOrderPage(), state)),
    GoRoute(
      path: '/cliente/client_orderstate',
      pageBuilder: (context, state) {
        // Recupera o ID do pedido dos extras
        final Map<String, dynamic>? extras =
            state.extra as Map<String, dynamic>?;
        final String orderId = extras?['orderId'] ?? '';
        return buildTransitionPage(
            ClientOrderStatePage(orderId: orderId), state);
      },
    ),
    GoRoute(
      path: '/cliente/client_support',
      name: 'client_support',
      pageBuilder: (context, state) {
        final Map<String, dynamic>? extras =
            state.extra as Map<String, dynamic>?;
        final String? orderId = extras?['orderId'];
        return buildTransitionPage(ClientSupportPage(orderId: orderId), state);
      },
    ),
    GoRoute(
      path: '/cliente/client_ordersummary',
      builder: (context, state) => ClientOrderSummaryPage(
        extra: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
        path: '/cliente/client_history',
        name: 'client_history',
        pageBuilder: (context, state) =>
            buildTransitionPage(const ClientHistoryPage(), state)),
    GoRoute(
        path: '/entregador/delivery_auth',
        name: 'delivery_auth',
        pageBuilder: (context, state) =>
            buildTransitionPage(const DeliveryAuthPage(), state)),
    GoRoute(
        path: '/entregador/delivery_home',
        name: 'delivery_home',
        pageBuilder: (context, state) =>
            buildTransitionPage(const DeliveryHomePage(), state)),
    GoRoute(
        path: '/entregador/delivery_profile',
        name: 'delivery_profile',
        pageBuilder: (context, state) =>
            buildTransitionPage(const DeliveryProfilePage(), state)),
    GoRoute(
        path: '/entregador/delivery_history',
        name: 'delivery_history',
        pageBuilder: (context, state) =>
            buildTransitionPage(const DeliveryHistoryPage(), state)),
    GoRoute(
        path: '/entregador/delivery_orderslist',
        name: 'delivery_orderslist',
        pageBuilder: (context, state) =>
            buildTransitionPage(const DeliveryOrdersListPage(), state)),
    GoRoute(
      path: '/entregador/delivery_orderstate',
      name: 'delivery_orderstate',
      pageBuilder: (context, state) {
        final Map<String, dynamic>? extras =
            state.extra as Map<String, dynamic>?;
        final String orderId = extras?['orderId'] ?? '';
        if (orderId.isEmpty) {
          print("AVISO: ID do pedido vazio em delivery_orderstate!");
        }
        return buildTransitionPage(
            DeliveryOrderStatePage(orderId: orderId), state);
      },
    ),
    GoRoute(
        path: '/entregador/delivery_support',
        name: 'delivery_support',
        pageBuilder: (context, state) {
          final Map<String, dynamic>? extras =
              state.extra as Map<String, dynamic>?;
          return buildTransitionPage(DeliverySupportPage(extra: extras), state);
        }),
    GoRoute(
      path: '/entregador/delivery_ordersummary',
      builder: (context, state) => DeliveryOrderSummaryPage(
        extra: state.extra as Map<String, dynamic>?,
      ),
    ),
  ],
);
