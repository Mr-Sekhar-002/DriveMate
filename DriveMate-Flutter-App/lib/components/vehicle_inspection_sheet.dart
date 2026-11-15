import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drivemate_models.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class VehicleInspectionSheet extends StatefulWidget {
  final Vehicle vehicle;
  final String bookingReference;

  const VehicleInspectionSheet({
    super.key,
    required this.vehicle,
    this.bookingReference = 'DM-RENT-2026',
  });

  static Future<bool?> show(BuildContext context, Vehicle vehicle, {String bookingReference = 'DM-RENT-2026'}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleInspectionSheet(vehicle: vehicle, bookingReference: bookingReference),
    );
  }

  @override
  State<VehicleInspectionSheet> createState() => _VehicleInspectionSheetState();
}

class _VehicleInspectionSheetState extends State<VehicleInspectionSheet> {
  final TextEditingController _odometerCtrl = TextEditingController(text: '14,250');
  final TextEditingController _damageNotesCtrl = TextEditingController();

  String _fuelLevel = '100% Full';
  bool _bodyClean = true;
  bool _tyresOk = true;
  bool _lightsOk = true;
  bool _acOk = true;
  bool _docsPresent = true;
  bool _hasExistingScratch = false;
  String _scratchLocation = 'Front Bumper';

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _damageNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Digital Vehicle Inspection',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${widget.vehicle.model} • Ref: ${widget.bookingReference}',
                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.borderSubtle, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ODOMETER & FUEL LEVEL
                    Text('1. Telemetry & Fuel Level', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _odometerCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Odometer (KM)',
                              labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              filled: true,
                              fillColor: AppColors.cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.speed_rounded, color: AppColors.accentCyan, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _fuelLevel,
                            dropdownColor: AppColors.cardBg,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Fuel Tank',
                              labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              filled: true,
                              fillColor: AppColors.cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.local_gas_station_rounded, color: AppColors.warningAmber, size: 20),
                            ),
                            items: const [
                              DropdownMenuItem(value: '100% Full', child: Text('100% Full')),
                              DropdownMenuItem(value: '75%', child: Text('75% Tank')),
                              DropdownMenuItem(value: '50%', child: Text('50% Tank')),
                              DropdownMenuItem(value: '25%', child: Text('25% Tank')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _fuelLevel = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 5-POINT CONDITION CHECKLIST
                    Text('2. 5-Point Physical Inspection', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildChecklistTile('Exterior Body & Paintwork', 'Checked for dents, rust or panel misalignments', _bodyClean, (v) => setState(() => _bodyClean = v)),
                    _buildChecklistTile('Tyres, Spare & Tool Kit', 'Adequate tread depth & jack kit present in boot', _tyresOk, (v) => setState(() => _tyresOk = v)),
                    _buildChecklistTile('Lighting & Indicators', 'Headlights, brake lamps & turn signals fully operational', _lightsOk, (v) => setState(() => _lightsOk = v)),
                    _buildChecklistTile('Air Conditioning & Infotainment', 'Cabin cooling and Bluetooth console working', _acOk, (v) => setState(() => _acOk = v)),
                    _buildChecklistTile('In-Car Documents Present', 'Original RC copy, Insurance, & PUC in glove box', _docsPresent, (v) => setState(() => _docsPresent = v)),
                    const SizedBox(height: 20),

                    // DAMAGE & SCRATCH REPORTING SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _hasExistingScratch ? AppColors.warningAmber.withOpacity(0.5) : AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.report_problem_outlined, color: AppColors.warningAmber, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Report Pre-Existing Scratch / Dent',
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _hasExistingScratch,
                                activeColor: AppColors.warningAmber,
                                onChanged: (val) => setState(() => _hasExistingScratch = val),
                              ),
                            ],
                          ),
                          if (_hasExistingScratch) ...[
                            const SizedBox(height: 12),
                            const Text('Dent Location', style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: ['Front Bumper', 'Left Door', 'Right Door', 'Rear Bumper', 'Windshield'].map((loc) {
                                final isSel = _scratchLocation == loc;
                                return ChoiceChip(
                                  label: Text(loc, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.textSecondary)),
                                  selected: isSel,
                                  selectedColor: AppColors.primaryBlue,
                                  backgroundColor: AppColors.bgSecondary,
                                  onSelected: (val) {
                                    if (val) setState(() => _scratchLocation = loc);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _damageNotesCtrl,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Note details (e.g. 2-inch scratch on lower lip)...',
                                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                filled: true,
                                fillColor: AppColors.bgSecondary,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // HANDOVER GUARANTEE
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.accentCyan, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'By confirming, you verify vehicle handover condition. Security deposit is auto-released to your wallet upon return verification.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Confirmation Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('CONFIRM DIGITAL INSPECTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () {
                    provider.showToast('Digital inspection confirmed! Vehicle verified for handover.');
                    Navigator.pop(context, true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? AppColors.successGreen.withOpacity(0.3) : AppColors.borderSubtle),
      ),
      child: CheckboxListTile(
        value: value,
        activeColor: AppColors.successGreen,
        checkColor: Colors.white,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
