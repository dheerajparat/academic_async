import 'package:academic_async/controllers/routine_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddRoutinePage extends StatefulWidget {
  const AddRoutinePage({super.key});

  @override
  State<AddRoutinePage> createState() => _AddRoutinePageState();
}

class _AddRoutinePageState extends State<AddRoutinePage> {
  final RoutineController controller = Get.find<RoutineController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _newPeriodController = TextEditingController();

  String? _selectedPeriod;
  String _selectedDay = 'monday';
  bool _isSaving = false;

  bool get _isNewPeriod => _selectedPeriod == '__new__';

  List<String> get _periodOptions => controller.periods;

  @override
  void dispose() {
    _subjectController.dispose();
    _newPeriodController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String? period = _isNewPeriod
        ? _newPeriodController.text
        : _selectedPeriod;
    if (period == null || period.trim().isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await controller.addOrUpdateEntry(
        period: period,
        day: _selectedDay,
        subject: _subjectController.text,
      );

      if (!mounted) {
        return;
      }

      Get.back();
      Get.snackbar(
        'Saved',
        'Routine updated successfully.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> periodOptions = _periodOptions;

    if (_selectedPeriod == null && periodOptions.isNotEmpty) {
      _selectedPeriod = periodOptions.first;
    } else if (_selectedPeriod != '__new__' &&
        _selectedPeriod != null &&
        !periodOptions.contains(_selectedPeriod)) {
      _selectedPeriod = periodOptions.isEmpty ? null : periodOptions.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Routine Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add or update a class slot',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose an existing period or create a new one, then assign the subject for a day.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Period',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select a period'),
                      items: <DropdownMenuItem<String>>[
                        ...periodOptions.map(
                          (String period) => DropdownMenuItem<String>(
                            value: period,
                            child: Text(period.toUpperCase()),
                          ),
                        ),
                        const DropdownMenuItem<String>(
                          value: '__new__',
                          child: Text('Add new period'),
                        ),
                      ],
                      onChanged: (String? value) {
                        setState(() => _selectedPeriod = value);
                      },
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select a period.';
                        }
                        return null;
                      },
                    ),
                    if (_isNewPeriod) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPeriodController,
                        decoration: const InputDecoration(
                          labelText: 'New period name',
                          hintText: 'e.g. period3',
                          border: OutlineInputBorder(),
                        ),
                        validator: (String? value) {
                          if (!_isNewPeriod) {
                            return null;
                          }
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a period name.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDay,
                      decoration: const InputDecoration(
                        labelText: 'Day',
                        border: OutlineInputBorder(),
                      ),
                      items: controller.dayKeys
                          .map(
                            (String dayKey) => DropdownMenuItem<String>(
                              value: dayKey,
                              child: Text(controller.dayLabel(dayKey)),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _selectedDay = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Mathematics',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveRoutine,
                child: Text(_isSaving ? 'Saving...' : 'Save Routine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
