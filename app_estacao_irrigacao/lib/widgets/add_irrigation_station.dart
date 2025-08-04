import 'package:flutter/material.dart';
import 'package:app_estacao_irrigacao/viewmodels/home_viewmodel.dart';
import 'package:app_estacao_irrigacao/models/irrigation_station.dart';

class AddIrrigationStationDialog extends StatefulWidget {
  final HomeViewModel viewModel;
  final IrrigationStation? station; // Estação para editar (opcional)

  const AddIrrigationStationDialog({
    super.key, 
    required this.viewModel,
    this.station,
  });

  @override
  State<AddIrrigationStationDialog> createState() => _AddIrrigationStationDialogState();
}

class _AddIrrigationStationDialogState extends State<AddIrrigationStationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlMqttController = TextEditingController();
  final _percentController = TextEditingController();
  final _millimetersController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.station != null;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (_isEditing && widget.station != null) {
      final station = widget.station!;
      _nameController.text = station.name;
      _urlMqttController.text = station.urlMqtt;

      if (station.percentForIrrigation >= 0) {
        _percentController.text = station.percentForIrrigation.toString();
      }
      
      if (station.millimetersWater >= 0) {
        _millimetersController.text = station.millimetersWater.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlMqttController.dispose();
    _percentController.dispose();
    _millimetersController.dispose();
    super.dispose();
  }

  Future<void> _addStation() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    bool success;
    if (_isEditing && widget.station != null) {
      success = await widget.viewModel.updateIrrigationStation(
        station: widget.station!,
        name: _nameController.text.trim(),
        urlMqtt: _urlMqttController.text.trim(),
        percentForIrrigation: double.tryParse(_percentController.text) ?? -1,
        millimetersWater: double.tryParse(_millimetersController.text) ?? -1,
      );
    } else {
      success = await widget.viewModel.addIrrigationStation(
        name: _nameController.text.trim(),
        urlMqtt: _urlMqttController.text.trim(),
        percentForIrrigation: double.tryParse(_percentController.text) ?? -1,
        millimetersWater: double.tryParse(_millimetersController.text) ?? -1,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing 
            ? 'Estação de irrigação atualizada com sucesso!' 
            : 'Estação de irrigação adicionada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.viewModel.errorMessage ?? 
            (_isEditing ? 'Erro ao atualizar estação' : 'Erro ao adicionar estação')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _buildDragIndicator(),
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragIndicator() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isEditing 
                ? 'Editar Estação de Irrigação' 
                : 'Adicionar Estação de Irrigação',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNameField(),
                  const SizedBox(height: 16),
                  _buildPercentField(),
                  const SizedBox(height: 16),
                  _buildMillimetersField(),
                  const SizedBox(height: 16),
                  _buildMqttField(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Nome da Estação',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nome é obrigatório';
        }
        if (value.trim().length < 3) {
          return 'Nome deve ter pelo menos 3 caracteres';
        }
        return null;
      },
      enabled: !_isLoading,
    );
  }

  Widget _buildMqttField() {
    return TextFormField(
      controller: _urlMqttController,
      decoration: const InputDecoration(
        labelText: 'URL Broker MQTT',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'A URL do Broker MQTT é obrigatória';
        }
        return null;
      },
      enabled: !_isLoading,
    );
  }

  Widget _buildPercentField() {
    return TextFormField(
      controller: _percentController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Percentual para Irrigação (%)',
        hintText: 'Ex: 75.5 (opcional)',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final percent = double.tryParse(value);
          if (percent == null) {
            return 'Digite um número válido';
          }
          if (percent < 0 || percent > 100) {
            return 'Percentual deve estar entre 0 e 100';
          }
        }
        return null;
      },
      enabled: !_isLoading,
    );
  }

  Widget _buildMillimetersField() {
    return TextFormField(
      controller: _millimetersController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Milímetros de Água',
        hintText: 'Ex: 12.5 (opcional)',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final mm = double.tryParse(value);
          if (mm == null) {
            return 'Digite um número válido';
          }
          if (mm < 0) {
            return 'Valor deve ser positivo';
          }
        }
        return null;
      },
      enabled: !_isLoading,
    );
  }

  Widget _buildActionButtons() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addStation,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Atualizar' : 'Adicionar'),
            ),
          ),
        ],
      ),
    );
  }
}