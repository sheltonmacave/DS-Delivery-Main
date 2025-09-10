import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:ds_delivery/services/user_role_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoleSwitcher extends StatelessWidget {
  final String currentRole;
  
  const RoleSwitcher({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    final otherRole = currentRole == 'cliente' ? 'entregador' : 'cliente';
    final otherRoleText = otherRole == 'cliente' ? 'Cliente' : 'Entregador';
    const Color highlightColor = Color(0xFFFF6A00);

    return FutureBuilder<bool>(
      future: _checkOtherRoleAvailable(otherRole),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink(); // Oculta se não tiver outra função
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: OutlinedButton.icon(
            icon: Icon(
              otherRole == 'cliente' ? Symbols.person : Symbols.directions_bike,
              color: highlightColor,
            ),
            label: Text(
              'Mudar para $otherRoleText',
              style: const TextStyle(color: highlightColor),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: highlightColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await saveUserRole(otherRole);
              if (otherRole == 'cliente') {
                context.go('/cliente/client_home');
              } else {
                context.go('/entregador/delivery_home');
              }
            },
          ),
        );
      },
    );
  }

  Future<bool> _checkOtherRoleAvailable(String otherRole) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final roles = data['roles'] as Map<String, dynamic>?;
      if (roles == null) return false;
      
      // Se for verificação para entregador, verifica também os dados do veículo
      if (otherRole == 'entregador' && roles[otherRole] == true) {
        final veiculo = data['veiculo'] as Map<String, dynamic>?;
        if (veiculo == null) return false;
        
        return veiculo['tipo']?.isNotEmpty == true && 
               veiculo['matricula']?.isNotEmpty == true;
      }
      
      return roles[otherRole] == true;
    } catch (e) {
      print('Erro ao verificar disponibilidade de função: $e');
      return false;
    }
  }
}