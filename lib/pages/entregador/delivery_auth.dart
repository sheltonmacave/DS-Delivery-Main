import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:ds_delivery/services/auth_service.dart';
import 'package:ds_delivery/services/firestore_service.dart';
import 'package:ds_delivery/services/storage_service.dart';
import 'package:ds_delivery/services/user_role_storage.dart';
import 'package:ds_delivery/services/auth_notifier.dart';

class DeliveryAuthPage extends StatefulWidget {
  const DeliveryAuthPage({super.key});

  @override
  State<DeliveryAuthPage> createState() => _DeliveryAuthPageState();
}

class _DeliveryAuthPageState extends State<DeliveryAuthPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final highlightColor = const Color(0xFFFF6A00);

  // Controllers para registro
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailRegisterController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordRegisterController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();

  // Controllers para login
  final TextEditingController _emailLoginController = TextEditingController();
  final TextEditingController _passwordLoginController = TextEditingController();

  // Estado
  late TabController _tabController;
  bool isLoginTab = false;
  bool _isRegistering = false;
  bool _isLoggingIn = false;

  // Imagem do perfil
  XFile? _selectedImageFile;

  // Dropdowns
  String? _zonaAtuacao = 'Maputo Cidade';
  String? _veiculoTipo = 'Motorizada';
  String? _veiculoCor = 'Preto';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailRegisterController.dispose();
    _phoneController.dispose();
    _passwordRegisterController.dispose();
    _confirmPasswordController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {
      isLoginTab = _tabController.index == 1;
    });
  }

  Future<void> _registerDelivery() async {
    if (_isRegistering) return;

    if (_passwordRegisterController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As senhas não coincidem")),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      final user = await _authService.registerWithEmailAndPassword(
        _emailRegisterController.text.trim(),
        _passwordRegisterController.text.trim(),
      );

      String? imageUrl = '';
      if (user != null) {
        await saveUserRole('entregador');
        authNotifier.notify();

        // Se tiver imagem, faz upload e pega URL
        if (_selectedImageFile != null) {
          imageUrl = await StorageService().uploadProfileImage(_selectedImageFile!, user.uid);
        }

        await _firestoreService.addUser(user, {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'photoURL': imageUrl ?? '',
          'roles': {
            'cliente': false,
            'entregador': true,
          },
          'zonaAtuacao': _zonaAtuacao ?? '',
          'veiculo': {
            'tipo': _veiculoTipo ?? '',
            'marca': _brandController.text,
            'modelo': _modelController.text,
            'matricula': _licensePlateController.text,
            'cor': _veiculoCor ?? '',
          },
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registro realizado com sucesso!")),
          );
          context.go('/entregador/delivery_home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao criar conta")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<void> _loginDelivery() async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
    });

    try {
      final user = await _authService.signInWithEmailAndPassword(
        _emailLoginController.text.trim(),
        _passwordLoginController.text.trim(),
      );

      if (user != null) {
        await saveUserRole('entregador');
        authNotifier.notify();
        context.go('/entregador/delivery_home');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login realizado com sucesso!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao fazer login")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  void _onImageSelected(XFile file) {
    setState(() {
      _selectedImageFile = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white),
          onPressed: () => context.go('/account_selection'),
        ),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color.fromARGB(80, 255, 255, 255), width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) {
                setState(() {
                  isLoginTab = index == 1;
                });
              },
              labelColor: highlightColor,
              unselectedLabelColor: Colors.white54,
              indicatorColor: highlightColor,
              tabs: const [
                Tab(text: 'Registrar'),
                Tab(text: 'Login'),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Image.asset(
              isLoginTab ? 'assets/images/login.png' : 'assets/images/cliente.png',
              height: 120,
            ),
            const SizedBox(height: 16),
            Text(
              isLoginTab ? 'Login como Entregador' : 'Registro como Entregador',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RegisterSection(
                    nameController: _nameController,
                    emailController: _emailRegisterController,
                    phoneController: _phoneController,
                    passwordController: _passwordRegisterController,
                    confirmPasswordController: _confirmPasswordController,
                    brandController: _brandController,
                    modelController: _modelController,
                    licensePlateController: _licensePlateController,
                    selectedImageFile: _selectedImageFile,
                    onImageUploaded: _onImageSelected,
                    zonaAtuacao: _zonaAtuacao,
                    onZonaAtuacaoChanged: (value) => setState(() => _zonaAtuacao = value),
                    veiculoTipo: _veiculoTipo,
                    onVeiculoTipoChanged: (value) => setState(() => _veiculoTipo = value),
                    veiculoCor: _veiculoCor,
                    onVeiculoCorChanged: (value) => setState(() => _veiculoCor = value),
                  ),
                  _LoginSection(
                    emailController: _emailLoginController,
                    passwordController: _passwordLoginController,
                    authService: _authService,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 6, top: 6),
          child: FilledButton(
            onPressed: (_isRegistering || _isLoggingIn)
                ? null
                : () {
                    if (isLoginTab) {
                      _loginDelivery();
                    } else {
                      _registerDelivery();
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: (_isRegistering || _isLoggingIn) ? Colors.grey : highlightColor,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isRegistering
                      ? 'Registrando...'
                      : _isLoggingIn
                          ? 'Entrando...'
                          : isLoginTab
                              ? 'Login'
                              : 'Registrar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                (_isRegistering || _isLoggingIn)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Symbols.check,
                        color: Colors.white,
                        size: 20,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== REGISTRO =====================

class _RegisterSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController licensePlateController;
  final XFile? selectedImageFile;
  final Function(XFile) onImageUploaded;
  final String? zonaAtuacao;
  final Function(String?) onZonaAtuacaoChanged;
  final String? veiculoTipo;
  final Function(String?) onVeiculoTipoChanged;
  final String? veiculoCor;
  final Function(String?) onVeiculoCorChanged;

  const _RegisterSection({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.brandController,
    required this.modelController,
    required this.licensePlateController,
    required this.selectedImageFile,
    required this.onImageUploaded,
    required this.zonaAtuacao,
    required this.onZonaAtuacaoChanged,
    required this.veiculoTipo,
    required this.onVeiculoTipoChanged,
    required this.veiculoCor,
    required this.onVeiculoCorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _ImageInsertionButton(
          onImageUploaded: onImageUploaded,
          selectedImageFile: selectedImageFile,
        ),
        _InputField(label: 'Nome', icon: Symbols.person, controller: nameController),
        _InputField(label: 'E-mail', icon: Symbols.mail, controller: emailController),
        _InputField(label: 'Número Ex: 821234567', icon: Symbols.phone, controller: phoneController),
        _InputField(label: 'Senha', icon: Symbols.lock, obscure: true, controller: passwordController),
        _InputField(label: 'Confirmação de Senha', icon: Symbols.lock_reset, obscure: true, controller: confirmPasswordController),
        _DropdownField(
          label: 'Zona de atuação',
          icon: Symbols.location_on,
          value: zonaAtuacao,
          options: const [
            'Maputo Cidade',
            'Maputo Província',
            'Gaza',
            'Inhambane',
            'Sofala',
            'Manica',
            'Tete',
            'Zambézia',
            'Nampula',
            'Niassa',
            'Cabo Delgado',
          ],
          onChanged: onZonaAtuacaoChanged,
        ),
        _DropdownField(
          label: 'Tipo de Transporte',
          icon: Symbols.emoji_transportation,
          value: veiculoTipo,
          options: const ['Motorizada', 'Carro'],
          onChanged: onVeiculoTipoChanged,
        ),
        _InputField(label: 'Marca', icon: Symbols.directions_car, controller: brandController),
        _InputField(label: 'Modelo', icon: Symbols.build, controller: modelController),
        _InputField(label: 'Matrícula', icon: Symbols.confirmation_number, controller: licensePlateController),
        _DropdownField(
          label: 'Cor do Veículo',
          icon: Symbols.palette,
          value: veiculoCor,
          options: const [
            'Preto',
            'Branco',
            'Cinzento',
            'Vermelho',
            'Azul',
            'Verde',
            'Amarelo',
            'Laranja',
            'Roxo',
          ],
          onChanged: onVeiculoCorChanged,
        ),
      ],
    );
  }
}

class _ImageInsertionButton extends StatefulWidget {
  final Function(XFile) onImageUploaded;
  final XFile? selectedImageFile;

  const _ImageInsertionButton({
    required this.onImageUploaded,
    required this.selectedImageFile,
  });

  @override
  State<_ImageInsertionButton> createState() => _ImageInsertionButtonState();
}

class _ImageInsertionButtonState extends State<_ImageInsertionButton> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndCropImage() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedImage.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Cortar Imagem',
              toolbarColor: Colors.deepOrange,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Cortar Imagem',
              aspectRatioLockEnabled: true,
              aspectRatioPickerButtonHidden: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          final croppedXFile = XFile(croppedFile.path);
          widget.onImageUploaded(croppedXFile);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nenhuma imagem foi cortada.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar imagem: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = widget.selectedImageFile;
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _pickAndCropImage,
          icon: const Icon(Symbols.add_photo_alternate, color: Colors.white),
          label: const Text('Inserir Imagem', style: TextStyle(color: Colors.white)),
        ),
        if (imageFile != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imageFile.path), height: 160, fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final Function(String?) onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const highlightColor = Color(0xFFFF6A00);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF1C1C1C),
        iconEnabledColor: Colors.white70,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: highlightColor, width: 2),
          ),
        ),
        items: options
            .map((v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(v),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;

  const _InputField({
    required this.label,
    required this.icon,
    this.obscure = false,
    this.controller,
  });

  @override
  State<_InputField> createState() => __InputFieldState();
}

class __InputFieldState extends State<_InputField> {
  final Color highlightColor = const Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.obscure,
        style: const TextStyle(color: Colors.white),
        cursorColor: highlightColor,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: widget.controller?.text.isNotEmpty ?? false ? highlightColor : Colors.white70,
          ),
          prefixIcon: Icon(widget.icon, color: widget.controller?.text.isNotEmpty ?? false ? highlightColor : Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: highlightColor, width: 2),
          ),
        ),
      ),
    );
  }
}

// ===================== LOGIN =====================

class _LoginSection extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AuthService authService;

  const _LoginSection({
    required this.emailController,
    required this.passwordController,
    required this.authService,
  });

  @override
  State<_LoginSection> createState() => _LoginSectionState();
}

class _LoginSectionState extends State<_LoginSection> {
  bool forgotPassword = false;
  bool _isResettingPassword = false;
  final TextEditingController _resetEmailController = TextEditingController();
  final Color highlightColor = const Color(0xFFFF6A00);

  @override
  void dispose() {
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira seu email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    try {
      await widget.authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de recuperação enviado! Verifique sua caixa de entrada'),
            backgroundColor: Colors.green,
          ),
        );
        // Fechar o dialog de recuperação de senha
        setState(() {
          forgotPassword = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _InputField(
          label: 'E-mail',
          icon: Symbols.mail,
          controller: widget.emailController,
        ),
        _InputField(
          label: 'Senha',
          icon: Symbols.lock,
          obscure: true,
          controller: widget.passwordController,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => forgotPassword = true),
            child: const Text(
              'Esqueci a senha',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        if (forgotPassword) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recuperação de Senha',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Insira seu email abaixo e enviaremos um link para redefinir sua senha.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _resetEmailController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: highlightColor,
                  decoration: InputDecoration(
                    labelText: 'Seu email',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Symbols.mail, color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: highlightColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isResettingPassword ? null : _resetPassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: _isResettingPassword ? Colors.grey : highlightColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isResettingPassword
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Enviar Link de Recuperação'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => forgotPassword = false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}