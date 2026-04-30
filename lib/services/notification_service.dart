import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/errors/app_exception.dart';

class NotificationService {
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      throw const NotificationException('Permission request failed');
    }
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
