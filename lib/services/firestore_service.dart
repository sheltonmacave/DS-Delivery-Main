import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Adiciona ou atualiza um utilizador no Firestore
  Future<void> addUser(User user, Map<String, dynamic> additionalData) async {
    try {
      print('Adicionando usuário ao Firestore com UID: ${user.uid}');
      print('Dados adicionais: $additionalData');

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': additionalData['name'] ?? '',
        'email': user.email ?? '',
        'phone': additionalData['phone'] ?? '',
        'photoURL': additionalData['photoURL'] ?? '',
        'roles': {
          'cliente': additionalData['roles']?['cliente'] ?? true,
          'entregador': additionalData['roles']?['entregador'] ?? false,
        },
        'clienteDesde': additionalData['roles']?['cliente'] == true
            ? FieldValue.serverTimestamp()
            : null,
        'entregadorDesde': additionalData['roles']?['entregador'] == true
            ? FieldValue.serverTimestamp()
            : null,
        'deleted': false,
        'zonaAtuacao': additionalData['zonaAtuacao'] ?? '',
        'veiculo': {
          'tipo': additionalData['veiculo']?['tipo'] ?? '',
          'marca': additionalData['veiculo']?['marca'] ?? '',
          'modelo': additionalData['veiculo']?['modelo'] ?? '',
          'matricula': additionalData['veiculo']?['matricula'] ?? '',
          'cor': additionalData['veiculo']?['cor'] ?? '',
        },
      }, SetOptions(merge: true));

      print('Usuário adicionado ao Firestore com sucesso!');
    } catch (e, stacktrace) {
      print('Erro ao adicionar usuário ao Firestore: $e');
      print('Stacktrace: $stacktrace');
      rethrow;
    }
  }

  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final roles = data['roles'] as Map<String, dynamic>;
    
    if (roles['cliente'] == true) return 'cliente';
    if (roles['entregador'] == true) return 'entregador';
    
    return null;
  }

  /// Obtém dados de um utilizador pelo UID
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('[FirestoreService] Erro ao obter usuário: $e');
    }
    return null;
  }

  /// Atualiza um campo específico do utilizador
  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      print('Atualizando campo $field para usuário $uid com valor: $value');
      await _firestore.collection('users').doc(uid).update({
        field: value,
      });
      print('Campo $field atualizado com sucesso!');
    } catch (e) {
      print('Erro ao atualizar campo $field: $e');
      rethrow;
    }
  }
}
