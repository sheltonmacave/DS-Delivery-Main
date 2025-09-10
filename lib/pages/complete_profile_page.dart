import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ds_delivery/services/user_role_storage.dart';

class CompleteProfilePage extends StatefulWidget {
  final String targetRole;
  
  const CompleteProfilePage({super.key, required this.targetRole});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  bool _isSaving = false;
  
  // Controllers para dados do entregador
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  String? _zonaAtuacao = 'Maputo Cidade';
  String? _veiculoTipo = 'Motorizada';
  String? _veiculoCor = 'Preto';
  
  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }
  
  Future<void> _saveAdditionalData() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go('/account_selection');
        return;
      }
      
      if (widget.targetRole == 'entregador') {
        // Atualizar ou adicionar dados de entregador
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'roles.entregador': true,
          'zonaAtuacao': _zonaAtuacao,
          'veiculo': {
            'tipo': _veiculoTipo,
            'marca': _brandController.text,
            'modelo': _modelController.text,
            'matricula': _licensePlateController.text,
            'cor': _veiculoCor,
          },
          'entregadorDesde': FieldValue.serverTimestamp(),
        });
        
        // Salvar função e redirecionar
        await saveUserRole('entregador');
        context.go('/entregador/delivery_home');
      } else {
        // Para cliente, apenas ativar a função
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'roles.cliente': true,
          'clienteDesde': FieldValue.serverTimestamp(),
        });
        
        await saveUserRole('cliente');
        context.go('/cliente/client_home');
      }
    } catch (e) {
      print('Erro ao salvar dados adicionais: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text(
          widget.targetRole == 'entregador' 
              ? 'Complete seu perfil de Entregador'
              : 'Complete seu perfil de Cliente',
          style: TextStyle(
            color: highlightColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                widget.targetRole == 'entregador'
                    ? Symbols.directions_bike
                    : Symbols.person,
                size: 64,
                color: highlightColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.targetRole == 'entregador'
                  ? 'Para começar a fazer entregas, precisamos de algumas informações adicionais.'
                  : 'Para usar a aplicação como cliente, clique em Continuar.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            if (widget.targetRole == 'entregador') ...[
              _buildDropdownField(
                'Zona de atuação',
                Symbols.location_on,
                _zonaAtuacao,
                const [
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
                (value) => setState(() => _zonaAtuacao = value),
              ),
              _buildDropdownField(
                'Tipo de Transporte',
                Symbols.emoji_transportation,
                _veiculoTipo,
                const ['Motorizada', 'Carro'],
                (value) => setState(() => _veiculoTipo = value),
              ),
              _buildInputField('Marca', Symbols.directions_car, _brandController),
              _buildInputField('Modelo', Symbols.build, _modelController),
              _buildInputField('Matrícula', Symbols.confirmation_number, _licensePlateController),
              _buildDropdownField(
                'Cor do Veículo',
                Symbols.palette,
                _veiculoCor,
                const [
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
                (value) => setState(() => _veiculoCor = value),
              ),
            ],
            
            const SizedBox(height: 32),
            
            FilledButton(
              onPressed: _isSaving ? null : _saveAdditionalData,
              style: FilledButton.styleFrom(
                backgroundColor: _isSaving ? Colors.grey : highlightColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Continuar como ${widget.targetRole == 'entregador' ? 'Entregador' : 'Cliente'}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.go('/account_selection'),
                child: const Text(
                  'Voltar',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label, 
    IconData icon, 
    TextEditingController controller
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        cursorColor: highlightColor,
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
            borderSide: BorderSide(color: highlightColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    IconData icon,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
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
            borderSide: BorderSide(color: highlightColor, width: 2),
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