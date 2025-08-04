import 'package:flutter/material.dart';

class MqttHelpDialog extends StatelessWidget {
  const MqttHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('Ajuda - Conexão MQTT'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Problemas comuns de conexão MQTT:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              Icons.wifi_off,
              'Sem Internet',
              'Verifique sua conexão com a internet.',
            ),
            _buildHelpItem(
              Icons.lock,
              'Credenciais Incorretas',
              'Confirme o email e senha do HiveMQ Cloud.',
            ),
            _buildHelpItem(
              Icons.cloud_off,
              'Servidor Indisponível',
              'O broker MQTT pode estar temporariamente fora do ar.',
            ),
            _buildHelpItem(
              Icons.settings,
              'URL do Broker',
              'Verifique se a URL da estação está correta (ex: xxxxx.s1.eu.hivemq.cloud).',
            ),
            const SizedBox(height: 16),
            const Text(
              'Para usar o HiveMQ Cloud:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Acesse hivemq.com/cloud\n'
              '2. Crie uma conta gratuita\n'
              '3. Anote o Cluster URL\n'
              '4. Crie um usuário com senha\n'
              '5. Use essas credenciais no app',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
