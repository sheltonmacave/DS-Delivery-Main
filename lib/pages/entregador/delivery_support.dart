import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ds_delivery/wrappers/back_handler.dart';

class DeliverySupportPage extends StatelessWidget {
  final Color highlightColor = const Color(0xFFFF6A00);
  final Map<String, dynamic>? extra;

  // Modificado para receber um mapa de extras em vez de apenas orderId
  const DeliverySupportPage({super.key, this.extra});

  @override
  Widget build(BuildContext context) {
    // Extrair o orderId do mapa de extras
    final String? orderId = extra != null ? extra!['orderId'] as String? : null;

    return BackHandler(
        alternativeRoute: '/entregador/delivery_orderstate',
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Column(
            children: [
              SafeArea(
                child: AppBar(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Symbols.arrow_back, color: Colors.white),
                    onPressed: () {
                      // Sempre navega para o estado do pedido se houver orderId, senão para a lista
                      if (orderId != null) {
                        context.go('/entregador/delivery_orderstate',
                            extra: {'orderId': orderId});
                      } else {
                        context.go('/entregador/delivery_orderslist');
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
                    _buildContactSection(orderId),
                    const SizedBox(height: 32),
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
                      'Como recebo notificações de novos pedidos?',
                      'Sempre que um novo pedido estiver disponível na tua zona de atuação, receberás uma notificação. Verifica também a página "Pedidos Disponíveis".',
                    ),
                    _buildFaqItem(
                      'O que fazer se o cliente não atender ou estiver ausente?',
                      'Aguarda por alguns minutos e tenta novo contacto. Se não conseguires, usa o botão "Reportar Problema" na página do pedido.',
                    ),
                    _buildFaqItem(
                      'Como confirmo a entrega?',
                      'Ao chegares ao destino, usa o botão "Confirmar Entrega" na página do pedido. O cliente poderá também confirmar no app dele.',
                    ),
                    _buildFaqItem(
                      'Como posso receber meus pagamentos?',
                      'Os pagamentos são processados semanalmente e depositados na conta bancária registrada no seu perfil. Verifique suas finanças na seção "Ganhos" do aplicativo.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildContactSection(String? orderId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEmailRow('dsdelivery@gmail.co.mz', orderId),
        const SizedBox(height: 12),
        _buildPhoneRow('+258 84 123 4567'),
        const SizedBox(height: 8),
        _buildPhoneRow('+258 82 765 4321'),
      ],
    );
  }

  Widget _buildEmailRow(String email, String? orderId) {
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
              query: orderId != null
                  ? 'subject=Suporte ao Entregador - Pedido #${orderId.substring(0, 4)}'
                  : 'subject=Suporte ao Entregador',
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
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                  Symbols.arrow_forward_ios,
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
