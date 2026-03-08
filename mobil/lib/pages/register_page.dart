import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FilteringTextInputFormatter;

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/patient.dart';
import '../models/triage_request.dart';
import '../services/storage_service.dart';
import '../services/triage_service.dart';
import '../utils/validators.dart';
import 'triage_result_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _tcCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  final _complaintCtrl = TextEditingController();
  String? _gender; // "E" / "K"
  Patient? _authPatient;

  List<Map<String, dynamic>> _categories = [];
  final Set<String> _picked = {};
  String _search = "";
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAuthAndCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tcCtrl.dispose();
    _birthYearCtrl.dispose();
    _complaintCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAuthAndCategories() async {
    final auth = await StorageService.getAuthPatient();
    if (auth != null) {
      _authPatient = auth;
      _nameCtrl.text = auth.fullName;
      _tcCtrl.text = auth.nationalId;
      if (auth.birthYear != null) {
        _birthYearCtrl.text = auth.birthYear.toString();
      }
      _gender = auth.gender;
    }
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final raw =
          await rootBundle.loadString('assets/patient_symptoms_by_category.json');
      final data = jsonDecode(raw);
      final list = (data['categories'] as List);

      _categories = list
          .map((e) => {
                'name': e['name']?.toString() ?? '',
                'items': (e['items'] as List).map((x) => x.toString()).toList(),
              })
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Kategori yükleme hatası: $e');
      setState(() {
        _loading = false;
        _errorMessage = AppStrings.errorLoadingSymptoms;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.errorLoadingSymptoms),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.selectAtLeastOneSymptom),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final tc = _tcCtrl.text.trim();
      
      // Aktif randevu kontrolü
      final queueStatus = await TriageService().fetchQueueStatus(tc);
      if (queueStatus != null && queueStatus.found == true && 
          (queueStatus.status == 'WAITING' || queueStatus.status == 'CALLED' || queueStatus.status == 'IN_PROGRESS')) {
        setState(() {
          _submitting = false;
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Aktif Randevu Mevcut'),
              content: Text(
                'Zaten aktif bir randevunuz bulunmaktadır.\n\n'
                'Sıra No: ${queueStatus.queueNumber}\n'
                'Durum: ${queueStatus.status}\n\n'
                'Lütfen mevcut randevunuz tamamlanana kadar yeni randevu oluşturmayın.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tamam'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TriageResultPage()),
                    );
                  },
                  child: const Text('Randevumu Gör'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final req = TriageRequest(
        fullName: _nameCtrl.text.trim(),
        nationalId: tc,
        symptoms: _picked.toList(),
        birthYear: _birthYearCtrl.text.trim().isNotEmpty
            ? int.tryParse(_birthYearCtrl.text.trim())
            : null,
        gender: _gender,
        chiefComplaint: _complaintCtrl.text.trim().isNotEmpty
            ? _complaintCtrl.text.trim()
            : null,
      );

      // submitTriage already handles offline fallback internally
      final apiResp = await TriageService().submitTriage(req);

      // Sıra bilgisi için backend kuyruğu dene (opsiyonel)
      final finalQueueStatus =
          await TriageService().fetchQueueStatus(req.nationalId);

      final queueNo = apiResp?.queueNumber ??
          finalQueueStatus?.queueNumber ??
          _generateQueueNumber();
      final estimatedWait = apiResp?.estimatedWaitMinutes ??
          finalQueueStatus?.estimatedWaitMinutes;
      final statusMessage = apiResp?.message ?? finalQueueStatus?.message;

      final p = Patient(
        fullName: req.fullName,
        nationalId: req.nationalId,
        symptoms: req.symptoms,
        queueNumber: queueNo,
        urgencyLabel: apiResp?.urgencyLabel ??
            AppStrings.evaluationRequired,
        urgencyLevel: apiResp?.urgencyLevel ?? 3,
        responseText: apiResp?.responseText ??
            AppStrings.defaultResponse,
        createdAt: DateTime.now(),
        estimatedWaitMinutes: estimatedWait,
        status: apiResp?.status ?? finalQueueStatus?.status,
        statusMessage: statusMessage,
      );

      await StorageService.saveLastPatient(p);

      if (!mounted) return;
      setState(() => _submitting = false);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TriageResultPage(),
        ),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Kayıt oluşturulurken hata oluştu: ${e.toString()}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? AppStrings.errorOccurred),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.registerTitle),
      ),

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: _submitting ? null : _submit,
            label: Text(
              _submitting ? 'Kaydediliyor...' : AppStrings.createRecord,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3F4FF),
              Color(0xFFF9F5FF),
              Color(0xFFF0FDF4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : _errorMessage != null && _categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCategories,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildFormHeader()),
                      SliverToBoxAdapter(child: _buildSearchCard()),
                      SliverList.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, ci) {
                          final cat = _categories[ci];
                          final title = cat['name'] as String;
                          final items = (cat['items'] as List).cast<String>();

                          final hasSearch = _search.trim().isNotEmpty;
                          final filtered = hasSearch
                              ? items
                                  .where((s) => s
                                      .toLowerCase()
                                      .contains(_search.toLowerCase()))
                                  .toList()
                              : items;

                          if (filtered.isEmpty && hasSearch) {
                            return const SizedBox.shrink();
                          }

                          final selectedCount =
                              items.where((s) => _picked.contains(s)).length;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  title: Text(
                                    title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4, right: 4, top: 6),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              selectedCount > 0
                                                  ? "$selectedCount ${AppStrings.selected.toLowerCase()}"
                                                  : "${AppStrings.itemsCount}: ${filtered.length}",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                for (final s in filtered) {
                                                  _picked.add(s);
                                                }
                                              });
                                            },
                                            child: const Text(AppStrings.selectAll),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                for (final s in filtered) {
                                                  _picked.remove(s);
                                                }
                                              });
                                            },
                                            child: const Text(AppStrings.clear),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, i) {
                                        final s = filtered[i];
                                        final selected = _picked.contains(s);
                                        return CheckboxListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4),
                                          visualDensity: VisualDensity.compact,
                                          title: Text(
                                            s,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          value: selected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _picked.add(s);
                                              } else {
                                                _picked.remove(s);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: AppStrings.fullName,
                prefixIcon: Icon(Icons.person),
              ),
              readOnly: _authPatient != null,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: Validators.validateFullName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tcCtrl,
              decoration: const InputDecoration(
                labelText: AppStrings.nationalId,
                prefixIcon: Icon(Icons.badge),
                counterText: "",
              ),
              keyboardType: TextInputType.number,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              readOnly: _authPatient != null,
              validator: Validators.validateTcKimlikNo,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _birthYearCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Doğum Yılı (opsiyonel)',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    readOnly: _authPatient != null,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null || parsed < 1900 || parsed > DateTime.now().year) {
                        return 'Geçerli bir yıl girin';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Cinsiyet (E/K)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'E', child: Text('Erkek (E)')),
                      DropdownMenuItem(value: 'K', child: Text('Kadın (K)')),
                    ],
                    onChanged: _authPatient != null ? null : (val) => setState(() => _gender = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintCtrl,
              decoration: const InputDecoration(
                labelText: 'Şikayet / Chief Complaint (opsiyonel)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: AppStrings.searchSymptom,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            // Seçili özet satırı (Wrap ile, taşma yapmaz)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(_picked.clear),
                icon: const Icon(Icons.clear),
                label: const Text(AppStrings.clearSelections),
              ),
            ),
            if (_picked.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${AppStrings.selected} (${_picked.length}):",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _picked
                    .take(12) // çoksa ilk 12 taneyi göster
                    .map(
                      (e) => Chip(
                        label: Text(
                          e,
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
              if (_picked.length > 12)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "+${_picked.length - 12} ${AppStrings.more}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  int _generateQueueNumber() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now % 1000) + 100;
  }
}
