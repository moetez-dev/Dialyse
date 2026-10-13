import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class ApiEndpoints {
  /// Django API origin (no trailing slash).
  ///
  /// Resolution order:
  /// 1. `--dart-define=API_BASE_URL=http://host:8000` (physical device / deploy)
  /// 2. Flutter Web: same hostname as the page (`localhost` vs `127.0.0.1`)
  /// 3. Android emulator: `http://10.0.2.2:8000`
  /// 4. iOS simulator / desktop: `http://localhost:8000`
  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.trim().isNotEmpty) {
      return _stripTrailingSlash(fromDefine.trim());
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://$host:8000';
      }
      if (host.isNotEmpty) {
        return 'http://$host:8000';
      }
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static String _stripTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  // Auth
  static const String login = '/api/login/';
  static const String logout = '/api/logout/';
  static const String profile = '/api/profile/';

  // Staff
  static const String doctors = '/api/doctors/';
  static const String nurses = '/api/nurses/';

  // Dashboard
  static const String dashboard = '/api/dashboard/';

  // Patients
  static const String patients = '/api/patients/';
  static const String patientDetail = '/api/patients/';

  // Machines
  static const String machines = '/api/machines/';
  static const String machineDetail = '/api/machines/';

  // Sessions / Seances
  static const String sessions = '/api/sessions/';
  static const String sessionDetail = '/api/sessions/';
  static const String sessionStart = '/api/sessions/';
  static const String sessionEnd = '/api/sessions/';
  static const String sessionCancel = '/api/sessions/';

  // Alerts
  static const String alerts = '/api/alerts/';
  static const String alertAck = '/api/alerts/';
  static const String alertResolve = '/api/alerts/';

  // Monitoring — canonical live feed is [monitoringLive] only.
  static const String monitoring = '/api/monitoring/';
  static const String monitoringLive = '/api/monitoring/live/';

  // Raspberry Pi / Edge pipeline (not used by staff UI)
  static const String pushMeasurement = '/api/push/';
  static const String seanceDebit = '/api/seance/debit/';
}
