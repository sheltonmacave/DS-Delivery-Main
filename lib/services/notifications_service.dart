import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // Importa o plugin global

Future<void> showLocalNotification({
  required String title,
  required String body,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'app_channel',
    'Notificações Gerais',
    channelDescription: 'Canal padrão para notificações locais',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID único
    title,
    body,
    details,
  );
}
