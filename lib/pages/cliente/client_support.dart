import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ds_delivery/wrappers/back_handler.dart';

class ClientSupportPage extends StatelessWidget {
  final Color highlightColor = const Color(0xFFFF6A00);
  final String? orderId;

  const ClientSupportPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    return BackHandler(
    alternativeRoute: '/cliente/client_orderstate',
    child: Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          // AppBar customizada com SafeArea
          SafeArea(
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.6),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Symbols.arrow_back, color: Colors.white),
                onPressed: () {
                  // Volta para a página anterior
                  if (orderId != null) {
                    context.go('/cliente/client_orderstate', extra: {'orderId': orderId});
                  } else {
                    context.pop();
                  }
                },
              ),
              title: const Text(
                'Suporte',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Conteúdo do body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Contactos da Equipe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _buildContactSection(),

                const SizedBox(height: 32),

                const Text(
                  'FAQ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFaqItem(
                  'Como posso acompanhar meu pedido?',
                  'Podes acompanhar o estado do teu pedido em tempo real na página "Estado do Pedido", com informações detalhadas do trajeto.',
                ),
                _buildFaqItem(
                  'Posso cancelar um pedido depois de feito?',
                  'Sim, enquanto o entregador ainda não tiver coletado a encomenda. Vai à página "Estado do Pedido" e toca em "Cancelar Pedido".',
                ),
                _buildFaqItem(
                  'Como entro em contacto com o entregador?',
                  'No estado do pedido, verás os contactos diretos do entregador, com opções de chamada ou mensagem.',
                ),
              ],
            ),
          )
        ],
      ),
    )
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEmailRow('dsdelivery@gmail.co.mz'),
        const SizedBox(height: 12),
        _buildPhoneRow('+258 84 123 4567'),
        const SizedBox(height: 8),
        _buildPhoneRow('+258 82 765 4321'),
      ],
    );
  }

  Widget _buildEmailRow(String email) {
    return Row(
      children: [
        Icon(Symbols.email, color: highlightColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            email,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        IconButton(
          icon: const Icon(Symbols.email, color: Colors.white),
          onPressed: () async {
            final Uri emailUri = Uri(
              scheme: 'mailto',
              path: email,
            );
            if (await canLaunchUrl(emailUri)) {
              await launchUrl(emailUri);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPhoneRow(String phoneNumber) {
    return Row(
      children: [
        Icon(Symbols.call, color: highlightColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            phoneNumber,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        IconButton(
          icon: const Icon(Symbols.call, color: Colors.white),
          onPressed: () async {
            final Uri phoneUri = Uri(
              scheme: 'tel',
              path: phoneNumber,
            );
            if (await canLaunchUrl(phoneUri)) {
              await launchUrl(phoneUri);
            }
          },
        ),
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 0),
        collapsedIconColor: highlightColor,
        iconColor: highlightColor,
        trailing: Icon(
          Symbols.expand_more,
          color: highlightColor,
        ),
        title: Text(
          question,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, right: 8),
            child: Text(
              answer,
              style: const TextStyle(color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1A1A1A),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
