import 'package:flutter/material.dart';
import 'package:app_estacao_irrigacao/viewmodels/home_viewmodel.dart';
import 'package:app_estacao_irrigacao/widgets/mqtt_help_dialog.dart';

class MqttConfigDialog extends StatefulWidget {
  final HomeViewModel viewModel;

  const MqttConfigDialog({super.key, required this.viewModel});

  @override
  State<MqttConfigDialog> createState() => _MqttConfigDialogState();
}

class _MqttConfigDialogState extends State<MqttConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Preencher com valores existentes se houver
    final client = widget.viewModel.client;
    _emailController.text = client.emailMqtt ?? '';
    _passwordController.text = client.passwordMqtt ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveMqttConfig() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    bool success = await widget.viewModel.updateMqttConfig(
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações MQTT salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.viewModel.errorMessage ?? 'Erro desconhecido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud_sync, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Configurar MQTT'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const MqttHelpDialog();
                },
              );
            },
            tooltip: 'Ajuda',
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Configure suas credenciais MQTT para conectar às estações de irrigação.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Username MQTT',
                hintText: 'Digite o username do broker MQTT',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username é obrigatório';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Senha MQTT',
                hintText: 'Digite a senha do broker MQTT',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Senha é obrigatória';
                }
                if (value.length < 3) {
                  return 'Senha deve ter pelo menos 3 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveMqttConfig,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
