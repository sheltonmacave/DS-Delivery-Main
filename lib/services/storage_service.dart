import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfileImage(XFile imageFile, String userId) async {
    try {
      // Referência fixa para foto de perfil
      final Reference storageRef = _storage
          .ref()
          .child('user_images/$userId/foto_perfil.jpg');

      final UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
      final TaskSnapshot downloadUrl = await uploadTask;
      final String url = await downloadUrl.ref.getDownloadURL();

      return url;
    } catch (e) {
      print('Erro ao fazer upload da imagem: $e');
      return null;
    }
  }

  Future<String?> uploadImage(XFile imageFile, String userId) async {
    try {
      final Reference storageRef = _storage
          .ref()
          .child('user_images/$userId/foto_perfil.jpg');

      final UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
      final TaskSnapshot downloadUrl = await uploadTask;
      final String url = await downloadUrl.ref.getDownloadURL();

      return url;
    } catch (e) {
      print('Erro ao fazer upload da imagem: $e');
      return null;
    }
  }

  Future<String?> getFotoPerfilUrl() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final ref = FirebaseStorage.instance
          .ref()
          .child("user_images/$userId/foto_perfil.jpg");

      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Erro ao buscar URL da foto de perfil: $e');
      return null;
    }
  }
}
