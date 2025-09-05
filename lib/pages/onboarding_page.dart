import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentIndex = 0;
  late Timer _timer;

  final List<Map<String, String>> _slides = [
    {
      'image': 'assets/images/onboarding1.png',
      'text': 'Transporte seguro e com responsabilidade',
    },
    {
      'image': 'assets/images/onboarding2.png',
      'text': 'Acompanhe o seu pedido em tempo real',
    },
    {
      'image': 'assets/images/onboarding3.png',
      'text': 'Entrega rápida, sem complicações',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    obterToken();
  }

  void obterToken() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print('🔑 TOKEN DO DISPOSITIVO: $token');
}

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _slides.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _slides[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text(
          'DS Delivery',
          style: TextStyle(
            color: Color(0xFFFF6A00),
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Image.asset(
                    current['image']!,
                    width: 280,
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    current['text']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  context.go('/account_selection');
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Avançar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    Icon(
                      Symbols.arrow_forward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
