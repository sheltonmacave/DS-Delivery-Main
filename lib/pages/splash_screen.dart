import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/order_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _checkActiveOrderAndNavigate();
  }

  Future<void> _checkActiveOrderAndNavigate() async {
    try {
      // Pequeno delay para permitir que a splash screen seja exibida
      await Future.delayed(const Duration(milliseconds: 500));

      // Verificar se o usuário está logado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Se não estiver logado, continue com o fluxo normal
        context.go('/account_selection');
        return;
      }

      // Buscar o papel do usuário das preferências
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      // Se não houver pedidos ativos ou ocorrer algum erro, continuar com o fluxo normal
      if (mounted) {
        context.go('/verifica');
      }
    } catch (e) {
      print('Erro ao verificar pedidos ativos: $e');
      // Em caso de erro, continuar com o fluxo normal
      if (mounted) {
        context.go('/verifica');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/icon.png',
              width: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Color(0xFFFF6A00),
            ),
          ],
        ),
      ),
    );
  }
}
