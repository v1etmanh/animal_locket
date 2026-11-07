import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BirthConsentScreen extends StatefulWidget {
  const BirthConsentScreen({super.key});

  @override
  State<BirthConsentScreen> createState() => _BirthConsentScreenState();
}

class _BirthConsentScreenState extends State<BirthConsentScreen> {
  DateTime? _birthDate;
  bool _accepted = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Thiết lập an toàn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Ngày sinh'),
          const SizedBox(height: 10),
          Text(
            'Mỗi độ tuổi có một không gian phù hợp.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ngày sinh chỉ dùng để xác định nhóm tuổi. Thông tin này không xuất hiện trên hồ sơ.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.cake_outlined),
            label: Text(
              _birthDate == null
                  ? 'Chọn ngày sinh'
                  : DateFormat('dd/MM/yyyy').format(_birthDate!),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
          const SizedBox(height: 18),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
            title: const Text(
              'Tôi đồng ý Điều khoản sử dụng và Chính sách riêng tư.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Tiếp tục',
            onPressed: _birthDate != null && _accepted
                ? () => context.go(
                    '/reveal?birthDate=${DateFormat('yyyy-MM-dd').format(_birthDate!)}',
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
