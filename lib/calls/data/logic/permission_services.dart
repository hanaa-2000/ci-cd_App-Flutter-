// lib/services/permission_service.dart — ملف جديد
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      // وجّه المستخدم لإعدادات التطبيق
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }
}