enum Environment {
  development,
  production,
}

class FlavorConfig {
  static Environment _environment = Environment.production; // Padrão: produção
  
  static Environment get environment => _environment;
  
  static bool get isDevelopment => _environment == Environment.development;
  static bool get isProduction => _environment == Environment.production;
  
  static void setEnvironment(Environment env) {
    _environment = env;
  }
  
  // Configurações específicas por ambiente
  static String get appName {
    switch (_environment) {
      case Environment.development:
        return 'Estação Irrigação (Dev)';
      case Environment.production:
        return 'Estação Irrigação';
    }
  }
  
  // URLs dos emuladores para desenvolvimento
  static const String authEmulatorHost = 'localhost';
  static const int authEmulatorPort = 9099;
  static const String firestoreEmulatorHost = 'localhost';
  static const int firestoreEmulatorPort = 8080;
}
