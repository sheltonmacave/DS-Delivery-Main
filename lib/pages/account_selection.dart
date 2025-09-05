import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';

class AccountSelectionPage extends StatefulWidget {
  const AccountSelectionPage({super.key});

  @override
  State<AccountSelectionPage> createState() => _AccountSelectionPageState();
}

class _AccountSelectionPageState extends State<AccountSelectionPage> {
  String? selectedRole;

  void selectRole(String role) {
    setState(() {
      selectedRole = role;
    });
  }

  void confirmSelection() {
    if (selectedRole == 'cliente') {
      context.go('/cliente/client_auth');
    } else if (selectedRole == 'entregador') {
      context.go('/entregador/delivery_auth');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Escolha o Tipo de Papel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _AccountOption(
              imagePath: 'assets/images/cliente.png',
              label: 'Sou Cliente',
              selected: selectedRole == 'cliente',
              onTap: () => selectRole('cliente'),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            _AccountOption(
              imagePath: 'assets/images/entregador.png',
              label: 'Sou Entregador',
              selected: selectedRole == 'entregador',
              onTap: () => selectRole('entregador'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: selectedRole == null ? null : confirmSelection,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Confirmar Papel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Icon(
                    Symbols.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  final String imagePath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AccountOption({
    required this.imagePath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const highlightColor = Color(0xFFFF6A00);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? highlightColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Image.asset(imagePath, width: 60, height: 60),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                color: selected ? highlightColor : Colors.white,
                fontSize: 22, // <-- texto maior
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
