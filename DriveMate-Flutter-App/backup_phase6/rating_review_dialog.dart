import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RatingReviewDialog extends StatefulWidget {
  final String driverName;
  final VoidCallback onDismiss;
  final Function(double rating, String comment) onSubmit;

  const RatingReviewDialog({
    super.key,
    required this.driverName,
    required this.onDismiss,
    required this.onSubmit,
  });

  @override
  State<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends State<RatingReviewDialog> {
  double _selectedRating = 5.0;
  final TextEditingController _commentController = TextEditingController(
    text: 'Great driving skills, polite chauffeur and punctual service!',
  );

  final List<String> _quickTags = [
    'Punctual',
    'Smooth Driving',
    'Clean Car',
    'Polite & Courteous',
    'Expert Navigation',
  ];
  final Set<String> _selectedTags = {'Punctual', 'Smooth Driving'};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Driver Avatar
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.navy900,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: AppColors.cyanAccent, size: 30),
            ),
            const SizedBox(height: 12),

            Text(
              'Rate ${widget.driverName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How was your chauffeured ride experience?',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),

            // 5 Star Rating Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                return IconButton(
                  icon: Icon(
                    starValue <= _selectedRating ? Icons.star : Icons.star_border,
                    color: AppColors.accentGold,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRating = starValue;
                    });
                  },
                );
              }),
            ),

            const SizedBox(height: 12),

            // Quick Tag Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.navy700)),
                  selected: isSelected,
                  selectedColor: AppColors.electricBlue,
                  backgroundColor: AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: isSelected ? AppColors.electricBlue : Colors.grey.shade300),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Comments input
            TextField(
              controller: _commentController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                hintText: 'Share more about your experience...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 18),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onDismiss,
                    child: const Text('Skip', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final tagsText = _selectedTags.isNotEmpty ? ' [${_selectedTags.join(', ')}]' : '';
                      final fullComment = '${_commentController.text.trim()}$tagsText';
                      widget.onSubmit(_selectedRating, fullComment);
                    },
                    child: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
