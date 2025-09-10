import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:ds_delivery/services/user_role_storage.dart';

class RoleVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Verifica se o usuário tem os dados necessários para a função específica
  Future<bool> hasRoleData(String uid, String role) async {
    try {
      final userData = await _firestore.collection('users').doc(uid).get();
      
      if (!userData.exists) return false;
      final data = userData.data()!;
      
      // Verifica se o usuário tem a função ativa
      final Map<String, dynamic> roles = data['roles'] ?? {};
      if (!(roles[role] == true)) return false;
      
      // Para entregadores, verificar se tem dados de veículo
      if (role == 'entregador') {
        final veiculo = data['veiculo'] as Map<String, dynamic>?;
        if (veiculo == null) return false;
        
        // Verifica campos obrigatórios do veículo
        return veiculo['tipo']?.isNotEmpty == true && 
               veiculo['marca']?.isNotEmpty == true &&
               veiculo['modelo']?.isNotEmpty == true &&
               veiculo['matricula']?.isNotEmpty == true;
      }
      
      // Para clientes, qualquer usuário com dados básicos pode ser cliente
      return true;
    } catch (e) {
      print('Erro ao verificar dados da função: $e');
      return false;
    }
  }

  /// Verifica a função do usuário após login e redireciona adequadamente
  Future<void> verifyRoleAccess(BuildContext context, String targetRole) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Não autenticado, voltar para tela inicial
      context.go('/account_selection');
      return;
    }

    // Verificar se tem os dados da função desejada
    final hasData = await hasRoleData(user.uid, targetRole);
    
    if (hasData) {
      // Salva a função atual e permite acesso
      await saveUserRole(targetRole);
      
      // Redireciona para a página inicial da função
      if (targetRole == 'cliente') {
        context.go('/cliente/client_home');
      } else {
        context.go('/entregador/delivery_home');
      }
    } else {
      // Mostrar tela de registro complementar
      context.go('/complete_profile', extra: {'targetRole': targetRole});
    }
  }
}