import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ds_delivery/services/user_role_storage.dart';

class AuthService {
  /// Obtém o número de telefone pelo email do utilizador.
  Future<String?> getPhoneByEmail(String email) async {
    try {
      print('Buscando telefone para email: [$email]');
      final firestore = FirebaseFirestore.instance;
      final query = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      print('Docs encontrados: ${query.docs.length}');
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        print('Data do usuário: $data');
        return data['phone'] as String?;
      }
      return null;
    } catch (e) {
      print('Erro ao buscar telefone por email: $e');
      return null;
    }
  }

  /// Envia um código SMS para o número de telefone fornecido.
  Future<void> sendSmsCode(
      String phone, Function(String verificationId) onCodeSent) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          print('Falha ao enviar SMS: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      print('Erro ao enviar código SMS: $e');
      rethrow;
    }
  }

  /// Verifica o código SMS recebido.
  Future<UserCredential> verifySmsCode(
      String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print('Erro ao verificar código SMS: $e');
      rethrow;
    }
  }

  /// Atualiza a senha do utilizador autenticado.
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Nenhum utilizador autenticado.');
      }
      await user.updatePassword(newPassword);
      print('Senha atualizada com sucesso.');
    } catch (e) {
      print('Erro ao atualizar senha: $e');
      rethrow;
    }
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registra um novo utilizador com email e senha.
  Future<User?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw ArgumentError("Email e senha não podem ser vazios.");
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user;
    } catch (e) {
      print('Erro ao registrar utilizador: $e');
      return null;
    }
  }

  /// Faz login com email e senha.
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw ArgumentError("Email e senha não podem ser vazios.");
      }

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user;
    } catch (e) {
      print('Erro ao fazer login: $e');
      return null;
    }
  }

  /// Login com conta Google.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        print('Login com Google cancelado pelo utilizador.');
        return null;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Erro ao fazer login com Google: $e');
      return null;
    }
  }

  /// Logout do utilizador atual.
  Future<void> logout() async {
    try {
      // Desconecta também do Google, se aplicável
      await GoogleSignIn().signOut();
      await _auth.signOut();
      await clearUserRole(); // <- limpa a role guardada
      print("Logout efetuado com sucesso.");
    } catch (e) {
      print('Erro ao fazer logout: $e');
      rethrow;
    }
  }

  Future<void> _deleteUserData(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    try {
      // 1. Primeiro, obtenha o documento do usuário para saber os papéis (roles)
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final roles = userData?['roles'] as Map<String, dynamic>?;
        final isCliente = roles?['cliente'] == true;
        final isEntregador = roles?['entregador'] == true;
        
        // 2. Apagar pedidos associados ao usuário
        if (isCliente) {
          // Apagar pedidos onde o usuário é cliente
          final clientPedidos = await firestore
              .collection('orders') // Usando o nome da coleção correto
              .where('clientId', isEqualTo: uid) // Campo correto baseado no seu modelo
              .get();
              
          for (var doc in clientPedidos.docs) {
            await doc.reference.delete();
          }
          
          print('${clientPedidos.docs.length} pedidos do cliente foram excluídos');
        }
        
        if (isEntregador) {
          // Atualizar pedidos onde o usuário é entregador (definir como nulo ou reassociar)
          final driverPedidos = await firestore
              .collection('orders')
              .where('driverId', isEqualTo: uid)
              .get();
              
          for (var doc in driverPedidos.docs) {
            // Opção 1: Excluir o pedido
            // await doc.reference.delete();
            
            // Opção 2: Redefinir para pendente e remover entregador
            await doc.reference.update({
              'driverId': null,
              'status': 0, // OrderStatus.pending.index
              'statusUpdates': FieldValue.arrayUnion([{
                'status': 0,
                'timestamp': DateTime.now().toIso8601String(),
                'description': 'Entregador removido do sistema'
              }])
            });
          }
          
          print('${driverPedidos.docs.length} pedidos do entregador foram atualizados');
        }
      }

      // 3. Apagar a imagem de perfil do Storage (usando o caminho correto)
      try {
        // Diretório do usuário no storage
        final userImagesRef = storage.ref().child('user_images').child(uid);
        
        // Listar todos os arquivos no diretório do usuário
        final listResult = await userImagesRef.listAll();
        
        // Excluir cada arquivo
        for (var item in listResult.items) {
          await item.delete();
          print('Arquivo excluído: ${item.fullPath}');
        }
        
        // Tentar excluir especificamente a foto de perfil
        await storage.ref().child('user_images/$uid/foto_perfil.jpg').delete();
        print('Foto de perfil excluída');
      } catch (e) {
        print('Erro ao excluir arquivos do Storage: $e');
        // Continua a execução mesmo se houver erro no Storage
      }

      // 4. Excluir o documento do usuário do Firestore
      await firestore.collection('users').doc(uid).delete();
      print("Documento do usuário excluído com sucesso");

      print("Dados do utilizador apagados com sucesso.");
    } catch (e) {
      print("Erro ao apagar dados do utilizador: $e");
      rethrow;
    }
  }

  Future<void> reauthenticateAndDelete(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("Utilizador não autenticado.");
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // Salva o UID antes de reautenticar
      final uid = user.uid;

      // Reautenticar antes de apagar
      await user.reauthenticateWithCredential(credential);

      // Apagar dados no Firestore e Storage
      await _deleteUserData(uid);

      // Apagar a conta no Firebase Auth
      await user.delete();

      // Limpar role nos SharedPreferences
      await clearUserRole();

      print("Conta e dados apagados com sucesso.");
    } catch (e) {
      print('Erro ao eliminar a conta: $e');
      rethrow;
    }
  }

  /// Reenvia um email de recuperação de senha.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      if (email.isEmpty) {
        throw ArgumentError("Email não pode ser vazio.");
      }

      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Erro ao enviar email de recuperação de senha: $e');
      rethrow;
    }
  }
}
