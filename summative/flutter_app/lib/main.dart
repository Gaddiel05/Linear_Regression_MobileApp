import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CO2 Emissions Predictor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7490)),
        useMaterial3: true,
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final TextEditingController _engineSizeController = TextEditingController();
  final TextEditingController _cylindersController = TextEditingController();
  final TextEditingController _fuelConsumptionCityController =
      TextEditingController();
  final TextEditingController _fuelConsumptionHwyController =
      TextEditingController();
  final TextEditingController _fuelConsumptionCombController =
      TextEditingController();
  final TextEditingController _fuelConsumptionCombMpgController =
      TextEditingController();

  String _result = '';
  bool _isLoading = false;
  Color _resultColor = Colors.black;

  // On web/desktop localhost is correct. 10.0.2.2 is only for Android emulator.
  String get apiUrl =>
      kIsWeb ? 'http://127.0.0.1:8000/predict' : 'http://10.0.2.2:8000/predict';

  Future<void> _predictCO2() async {
    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'enginesize': double.parse(_engineSizeController.text),
          'cylinders': int.parse(_cylindersController.text),
          'fuelconsumption_city': double.parse(
            _fuelConsumptionCityController.text,
          ),
          'fuelconsumption_hwy': double.parse(
            _fuelConsumptionHwyController.text,
          ),
          'fuelconsumption_comb': double.parse(
            _fuelConsumptionCombController.text,
          ),
          'fuelconsumption_comb_mpg': int.parse(
            _fuelConsumptionCombMpgController.text,
          ),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediction = data['predicted_co2emissions'];
        setState(() {
          _result =
              'Predicted CO2 Emissions: ${prediction.toStringAsFixed(2)} g/km';
          _resultColor = Colors.green;
        });
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final errorDetail = data['detail'] ?? 'Validation error';
        setState(() {
          _result = 'Error: $errorDetail';
          _resultColor = Colors.red;
        });
      } else {
        setState(() {
          _result = 'Error: ${response.statusCode} - ${response.body}';
          _resultColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Connection Error: $e\nMake sure your API is running.';
        _resultColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateInputs() {
    try {
      final engineSize = double.parse(_engineSizeController.text);
      final cylinders = int.parse(_cylindersController.text);
      final fuelConsumptionCity = double.parse(
        _fuelConsumptionCityController.text,
      );
      final fuelConsumptionHwy = double.parse(
        _fuelConsumptionHwyController.text,
      );
      final fuelConsumptionComb = double.parse(
        _fuelConsumptionCombController.text,
      );
      final fuelConsumptionCombMpg = int.parse(
        _fuelConsumptionCombMpgController.text,
      );

      // Validate ranges according to API schema
      if (engineSize <= 0.5 || engineSize > 10.0) {
        _showError('Engine Size must be between 0.5 and 10.0');
        return false;
      }
      if (cylinders < 2 || cylinders > 16) {
        _showError('Cylinders must be between 2 and 16');
        return false;
      }
      if (fuelConsumptionCity <= 1.0 || fuelConsumptionCity > 40.0) {
        _showError('City Fuel Consumption must be between 1.0 and 40.0');
        return false;
      }
      if (fuelConsumptionHwy <= 1.0 || fuelConsumptionHwy > 35.0) {
        _showError('Highway Fuel Consumption must be between 1.0 and 35.0');
        return false;
      }
      if (fuelConsumptionComb <= 1.0 || fuelConsumptionComb > 40.0) {
        _showError('Combined Fuel Consumption must be between 1.0 and 40.0');
        return false;
      }
      if (fuelConsumptionCombMpg < 5 || fuelConsumptionCombMpg > 100) {
        _showError('Combined MPG must be between 5 and 100');
        return false;
      }
      return true;
    } catch (e) {
      _showError('Invalid input: Please enter valid numbers');
      return false;
    }
  }

  void _showError(String message) {
    setState(() {
      _result = 'Error: $message';
      _resultColor = Colors.red;
    });
  }

  @override
  void dispose() {
    _engineSizeController.dispose();
    _cylindersController.dispose();
    _fuelConsumptionCityController.dispose();
    _fuelConsumptionHwyController.dispose();
    _fuelConsumptionCombController.dispose();
    _fuelConsumptionCombMpgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'CO2 Emissions Predictor',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFECFEFF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the vehicle data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel('Engine Size (Liters)'),
              _buildTextField(_engineSizeController, 'e.g., 2.0'),
              const SizedBox(height: 12),
              _buildLabel('Cylinders'),
              _buildTextField(_cylindersController, 'e.g., 4', isInteger: true),
              const SizedBox(height: 12),
              _buildLabel('City Fuel Consumption (L/100km)'),
              _buildTextField(_fuelConsumptionCityController, 'e.g., 9.9'),
              const SizedBox(height: 12),
              _buildLabel('Highway Fuel Consumption (L/100km)'),
              _buildTextField(_fuelConsumptionHwyController, 'e.g., 7.0'),
              const SizedBox(height: 12),
              _buildLabel('Combined Fuel Consumption (L/100km)'),
              _buildTextField(_fuelConsumptionCombController, 'e.g., 8.6'),
              const SizedBox(height: 12),
              _buildLabel('Combined Fuel Consumption (MPG)'),
              _buildTextField(
                _fuelConsumptionCombMpgController,
                'e.g., 33',
                isInteger: true,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : _predictCO2,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 21,
                    horizontal: 16,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: const Color(0x29000000),
                  elevation: 6,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Predict'),
              ),
              const SizedBox(height: 24),
              if (_result.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _resultColor == Colors.green
                        ? const Color(0xFFE8F7EE)
                        : const Color(0xFFFDECEC),
                    border: Border.all(color: _resultColor, width: 1.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _result,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _resultColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isInteger = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isInteger
          ? const TextInputType.numberWithOptions(signed: false)
          : const TextInputType.numberWithOptions(decimal: true, signed: false),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E7490), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        prefixIcon: const Icon(Icons.tune, color: Color(0xFF0E7490)),
      ),
    );
  }
}
