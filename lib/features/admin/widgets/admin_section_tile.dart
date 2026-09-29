import 'package:flutter/material.dart';

// =============================================================================
// AdminSectionTile
// Navigation tile used in the Admin Dashboard section drawer/list.
// =============================================================================

class AdminSectionTile extends StatelessWidget {
  const AdminSectionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool isSelected;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF184797).withAlpha(12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF184797).withAlpha(60)
                : const Color(0xFFE4E7EC),
          ),
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF184797).withAlpha(20)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF184797)
                    : const Color(0xFF667085),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF184797)
                          : const Color(0xFF263238),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            // Badge
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF184797),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF98A2B3)),
          ],
        ),
      ),
    );
  }
}
