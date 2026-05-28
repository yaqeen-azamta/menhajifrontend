class Env {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static String get apiBase => '$backendUrl/api';
}
