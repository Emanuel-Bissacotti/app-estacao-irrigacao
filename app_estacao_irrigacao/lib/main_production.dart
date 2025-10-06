import 'package:app_estacao_irrigacao/config/flavor_config.dart';
import 'package:app_estacao_irrigacao/main.dart' as main_app;

void main() async {
  // Configura o ambiente de produção
  FlavorConfig.setEnvironment(Environment.production);
  
  // Executa o app principal
  main_app.main();
}
