import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackHandler extends StatefulWidget {
  final Widget child;
  final bool isRoot;
  final String? alternativeRoute;
  final bool showExitWarning;
  
  const BackHandler({
    super.key, 
    required this.child,
    this.isRoot = false,
    this.alternativeRoute,
    this.showExitWarning = false,
  });

  @override
  State<BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<BackHandler> {
  DateTime? _lastPressedAt;

  Future<bool> _handleWillPop() async {
    // Se não for uma tela raiz (home), simplesmente permita o pop normal
    if (!widget.isRoot) {
      if (widget.alternativeRoute != null && mounted) {
        context.go(widget.alternativeRoute!);
        return false; // Não executar pop padrão, vamos redirecionar
      }
      return true; // Executar pop normal (voltar à tela anterior)
    }
    
    // Se for uma tela raiz, implementar o "pressione novamente para sair"
    if (widget.showExitWarning) {
      final now = DateTime.now();
      if (_lastPressedAt == null || 
          now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
        _lastPressedAt = now;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pressione novamente para sair'),
          duration: Duration(seconds: 2),
        ));
        return false; // Não feche o app ainda
      }
      
      // Se pressionado duas vezes em 2 segundos, fecha o app
      return true;
    }
    
    // Para telas raiz sem aviso, apenas permita o pop
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: widget.child,
    );
  }
}