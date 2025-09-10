import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ds_delivery/services/auth_service.dart';
import 'package:ds_delivery/services/auth_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ds_delivery/widgets/role_switcher_widget.dart';
import 'package:ds_delivery/wrappers/back_handler.dart';

class ImagemDoStorage extends StatelessWidget {
  final String caminhoDaImagem; // Ex.: "imagens/perfil.jpg"

  const ImagemDoStorage({super.key, required this.caminhoDaImagem});

  Future<String> _getDownloadUrl() async {
    return await FirebaseStorage.instance
        .ref(caminhoDaImagem)
        .getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getDownloadUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return const Icon(Icons.error);
        }
        return Image.network(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  int _currentIndex = 2;
  String? _userRole;
  int? _monthsOnPlatform;
  String? _userName;
  String? _userPhone;
  String? _userEmail;
  String? _imageUrl; // URL da imagem do perfil, se disponível
  File? _profileImage;
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Supondo que tens o UID do user:
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pega os dados do Firestore, por exemplo na coleção 'users':
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!doc.exists) return;

    final data = doc.data();

    if (data == null) return;

    // Supondo que guardas estes campos no documento:
    setState(() {
      _userRole = data['role'] as String?;
      _userName = data['name'] as String?;
      _userPhone = data['phone'] as String?;
      _userEmail = user.email;  // email normalmente vem do auth, mas podes substituir
      _imageUrl = data['photoURL'] as String?;
      
      _nameController.text = _userName ?? '';
      _phoneController.text = _userPhone ?? '';
      _emailController.text = _userEmail ?? '';
      
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        print('[v0] Profile image URL loaded from Firestore: $_imageUrl');
      } else {
        print('[v0] No profile image URL found in Firestore');
      }
      
      // Calcula meses na plataforma (exemplo simples):
      final createdTimestamp = data['createdAt'] as Timestamp?;
      if (createdTimestamp != null) {
        final createdDate = createdTimestamp.toDate();
        final now = DateTime.now();
        _monthsOnPlatform = (now.year - createdDate.year) * 12 + (now.month - createdDate.month);
      } else {
        _monthsOnPlatform = 0;
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update Firestore document
      Map<String, dynamic> updates = {};
      
      if (_nameController.text.trim() != _userName) {
        updates['name'] = _nameController.text.trim();
      }
      
      if (_phoneController.text.trim() != _userPhone) {
        updates['phone'] = _phoneController.text.trim();
      }

      // Handle image upload if new image selected
      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user.uid}/foto_perfil.jpg');
        
        await storageRef.putFile(_profileImage!);
        final downloadUrl = await storageRef.getDownloadURL();
        updates['photoURL'] = downloadUrl;
      }

      // Update Firestore if there are changes
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updates);
      }

      // Update local state
      setState(() {
        if (updates.containsKey('name')) _userName = _nameController.text.trim();
        if (updates.containsKey('phone')) _userPhone = _phoneController.text.trim();
        if (updates.containsKey('photoURL')) {
          _imageUrl = updates['photoURL'];
          _profileImage = null; // Clear local file after upload
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil atualizado com sucesso!'),
            backgroundColor: highlightColor,
          ),
        );
      }
    } catch (e) {
      print('[v0] Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar perfil. Tenta novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _showConfirmationDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.75),
                  border: Border.all(color: highlightColor, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.info, color: highlightColor, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            backgroundColor: const Color(0xFF2A2A2A),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Não'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onConfirm();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: highlightColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Sim'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.75),
                  border: Border.all(color: highlightColor, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.warning, color: highlightColor, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Eliminar Conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Confirma a tua senha para eliminar a conta permanentemente. Esta ação é irreversível.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        labelText: 'Senha',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: highlightColor, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            backgroundColor: const Color(0xFF2A2A2A),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await AuthService().reauthenticateAndDelete(passwordController.text.trim());
                              if (context.mounted) context.go('/');
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Erro ao eliminar conta. Verifica a senha.'),
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Eliminar'),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/cliente/client_history');
        break;
      case 1:
        context.go('/cliente/client_home');
        break;
      case 2:
        context.go('/cliente/client_profile');
        break;
    }
  }

  void _openEditSheet() {
    _nameController.text = _userName ?? '';
    _phoneController.text = _userPhone ?? '';
    _emailController.text = _userEmail ?? '';
    _profileImage = null; // Reset selected image
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF2A2A2A),
                    child: _profileImage != null
                        ? ClipOval(
                            child: Image.file(
                              _profileImage!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _imageUrl != null && _imageUrl!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  _imageUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Symbols.person,
                                      size: 40,
                                      color: Colors.white54,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Symbols.person,
                                size: 40,
                                color: Colors.white54,
                              ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: highlightColor,
                      radius: 14,
                      child: const Icon(
                        Symbols.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField('Nome', _nameController),
            _buildInputField('Número', _phoneController),
            _buildInputField('Email', _emailController, enabled: false), // Email não editável
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isUpdating ? null : _saveProfileChanges,
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isUpdating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Guardando...', style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.save, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Guardar Alterações', style: TextStyle(color: Colors.white)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller, // Added controller
        enabled: enabled, // Added enabled parameter
        style: TextStyle(color: enabled ? Colors.white : Colors.white54),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: highlightColor, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool selected) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? highlightColor : Colors.white54),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? highlightColor : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
    alternativeRoute: '/cliente/client_home',
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text(
          'Perfil',
          style: TextStyle(
            color: highlightColor,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Symbols.edit, color: highlightColor),
            onPressed: _openEditSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF2A2A2A),
                  child: _imageUrl != null && _imageUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _imageUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('[v0] Error loading profile image: $error');
                              return const Icon(
                                Symbols.person,
                                size: 40,
                                color: Colors.white54,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                print('[v0] Profile image loaded successfully');
                                return child;
                              }
                              print('[v0] Loading profile image... ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
                              return const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Symbols.person,
                          size: 40,
                          color: Colors.white54,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.person, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  _userRole ?? 'Cliente',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Na plataforma há ${_monthsOnPlatform ?? 0} meses',
              style: const TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Symbols.badge, color: Colors.white),
              title: Text(
                _userName ?? 'Nome do utilizador',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.phone, color: Colors.white),
              title: Text(
                _userPhone ?? '+258 00 000 0000',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.mail, color: Colors.white),
              title: Text(
                _userEmail ?? 'email@exemplo.com',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Área Perigosa', style: TextStyle(color: Color.fromARGB(255, 168, 168, 168))),
            ),
            const Divider(color: Color.fromARGB(255, 168, 168, 168)),
            const RoleSwitcher(currentRole: 'cliente'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                _showConfirmationDialog(
                  'Confirmar Logout',
                  'Tens a certeza que queres fazer logout?',
                  () async{
                    await AuthService().logout();
                    final prefs = await SharedPreferences.getInstance();
                    prefs.remove('user_role');
                    authNotifier.notify(); // <- força router a redirecionar para login
                    context.go('/verifica');
                  },
                );
              },
              icon: const Icon(Symbols.logout, color: Colors.white),
              label: const Text('Logout', style: TextStyle(color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(200, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _showDeleteAccountDialog(context),
              icon: const Icon(Symbols.delete_forever, color: Colors.white),
              label: const Text('Eliminar Perfil', style: TextStyle(color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(200, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final horizontalMargin = MediaQuery.of(context).size.width * 0.05;
          return Padding(
            padding: EdgeInsets.only(
              bottom: 20,
              left: horizontalMargin,
              right: horizontalMargin,
            ),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(200, 15, 15, 15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: highlightColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: highlightColor.withAlpha(100),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(Symbols.history, 'Histórico', 0, _currentIndex == 0),
                  _buildNavItem(Symbols.home, 'Início', 1, _currentIndex == 1),
                  _buildNavItem(Symbols.person, 'Perfil', 2, _currentIndex == 2),
                ],
              ),
            ),
          );
        },
      ),
    )
    );
  }
}
