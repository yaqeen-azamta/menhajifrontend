class Env {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://192.168.0.192:8080',
  );

  static String get apiBase => '$backendUrl/api';
}
