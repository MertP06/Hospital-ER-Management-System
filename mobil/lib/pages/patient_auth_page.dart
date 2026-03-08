import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/validators.dart';
import 'home_page.dart';

class PatientAuthPage extends StatefulWidget {
  const PatientAuthPage({super.key});

  @override
  State<PatientAuthPage> createState() => _PatientAuthPageState();
}

class _PatientAuthPageState extends State<PatientAuthPage> {
  final _registerForm = GlobalKey<FormState>();
  final _loginForm = GlobalKey<FormState>();

  final _regName = TextEditingController();
  final _regTc = TextEditingController();
  final _regBirth = TextEditingController();
  String? _regGender;

  final _loginName = TextEditingController();
  final _loginTc = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _regName.dispose();
    _regTc.dispose();
    _regBirth.dispose();
    _loginName.dispose();
    _loginTc.dispose();
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_registerForm.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patient = Patient(
        fullName: _regName.text.trim(),
        nationalId: _regTc.text.trim(),
        birthYear: _regBirth.text.trim().isNotEmpty
            ? int.tryParse(_regBirth.text.trim())
            : null,
        gender: _regGender,
        symptoms: const [],
        queueNumber: 0,
        urgencyLabel: '',
        urgencyLevel: 0,
        responseText: '',
      );
      final saved = await AuthService().register(patient);
      await StorageService.saveAuthPatient(saved);
      _goHome();
    } catch (e) {
      setState(() => _error = 'Kayıt başarısız: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doLogin() async {
    if (!_loginForm.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await AuthService()
          .login(tc: _loginTc.text.trim(), name: _loginName.text.trim());
      await StorageService.saveAuthPatient(p);
      _goHome();
    } catch (e) {
      setState(() => _error = 'Giriş başarısız: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 12),
              _buildRegisterCard(),
              const SizedBox(height: 16),
              _buildLoginCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Acil Triage - Hasta',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Kayıt ol veya TC/İsim ile giriş yap.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _registerForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kayıt Ol',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regName,
                decoration: const InputDecoration(
                  labelText: AppStrings.fullName,
                  prefixIcon: Icon(Icons.person),
                ),
                validator: Validators.validateFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regTc,
                decoration: const InputDecoration(
                  labelText: AppStrings.nationalId,
                  prefixIcon: Icon(Icons.badge),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.validateTcKimlikNo,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _regBirth,
                      decoration: const InputDecoration(
                        labelText: 'Doğum Yılı (opsiyonel)',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _regGender,
                      decoration: const InputDecoration(
                        labelText: 'Cinsiyet (E/K)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'E', child: Text('Erkek (E)')),
                        DropdownMenuItem(value: 'K', child: Text('Kadın (K)')),
                      ],
                      onChanged: (v) => setState(() => _regGender = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _doRegister,
                  child: Text(_loading ? 'Gönderiliyor...' : 'Kayıt Ol'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _loginForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _loginName,
                decoration: const InputDecoration(
                  labelText: AppStrings.fullName,
                  prefixIcon: Icon(Icons.person),
                ),
                validator: Validators.validateFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _loginTc,
                decoration: const InputDecoration(
                  labelText: AppStrings.nationalId,
                  prefixIcon: Icon(Icons.badge),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.validateTcKimlikNo,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : _doLogin,
                  child: Text(_loading ? 'Kontrol ediliyor...' : 'Giriş Yap'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

