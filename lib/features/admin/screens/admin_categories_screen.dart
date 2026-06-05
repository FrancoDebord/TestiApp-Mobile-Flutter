import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../providers/admin_provider.dart';

// =============================================================================
// AdminCategoriesScreen — Add / Edit / Reorder categories
//
// Widget tree:
//   Column
//     _AddCategoryBar
//     Expanded → ReorderableListView.builder
//                  _CategoryTile (drag handle, name, count, edit/toggle)
// =============================================================================

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminCategoriesProvider);

    return Column(
      children: [
        _AddCategoryBar(
          onAdd: (name) {
            final newCat = AppCategory(
              id: 'c${categories.length + 1}',
              name: name,
              slug: name.toLowerCase().replaceAll(' ', '-'),
              order: categories.length + 1,
              testimonyCount: 0,
            );
            ref.read(adminCategoriesProvider.notifier).update([
              ...categories,
              newCat,
            ]);
          },
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              final updated = [...categories];
              if (newIndex > oldIndex) newIndex--;
              final item = updated.removeAt(oldIndex);
              updated.insert(newIndex, item);
              ref.read(adminCategoriesProvider.notifier).update(updated);
            },
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _CategoryTile(
                key: ValueKey(cat.id),
                category: cat,
                onEdit: () => _showEditDialog(context, ref, cat, categories),
                onToggle: () {
                  final updated = categories
                      .map((c) => c.id == cat.id
                          ? AppCategory(
                              id: c.id,
                              name: c.name,
                              slug: c.slug,
                              order: c.order,
                              testimonyCount: c.testimonyCount,
                              isActive: !c.isActive,
                            )
                          : c)
                      .toList();
                  ref.read(adminCategoriesProvider.notifier).update(updated);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AppCategory cat,
    List<AppCategory> categories,
  ) {
    final controller = TextEditingController(text: cat.name);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier la catégorie',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF0F172A))),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nom de la catégorie',
            hintStyle: const TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF6B21A8), width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updated = categories
                    .map((c) => c.id == cat.id
                        ? AppCategory(
                            id: c.id,
                            name: newName,
                            slug: newName.toLowerCase().replaceAll(' ', '-'),
                            order: c.order,
                            testimonyCount: c.testimonyCount,
                            isActive: c.isActive,
                          )
                        : c)
                    .toList();
                ref.read(adminCategoriesProvider.notifier).update(updated);
              }
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B21A8),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer',
                style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Add category bar ─────────────────────────────────────────────────────────

class _AddCategoryBar extends StatefulWidget {
  const _AddCategoryBar({required this.onAdd});
  final void Function(String name) onAdd;

  @override
  State<_AddCategoryBar> createState() => _AddCategoryBarState();
}

class _AddCategoryBarState extends State<_AddCategoryBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Nouvelle catégorie…',
                hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF6B21A8), width: 1.5)),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () {
                      widget.onAdd(_controller.text.trim());
                      _controller.clear();
                      setState(() {});
                    },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Ajouter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
                elevation: 0,
                textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category tile ────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onToggle,
    super.key,
  });

  final AppCategory category;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: category.isActive ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: category.isActive
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          const Icon(Icons.drag_handle_rounded,
              size: 18, color: Color(0xFFCBD5E1)),
          const SizedBox(width: 10),
          // Order number
          SizedBox(
            width: 22,
            child: Text(
              '${category.order}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              category.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: category.isActive
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
                decoration: category.isActive
                    ? null
                    : TextDecoration.lineThrough,
              ),
            ),
          ),
          // Count badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${category.testimonyCount}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: Color(0xFF6B21A8)),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Modifier',
          ),
          const SizedBox(width: 6),
          // Active toggle
          Switch(
            value: category.isActive,
            onChanged: (_) => onToggle(),
            activeThumbColor: const Color(0xFF6B21A8),
            activeTrackColor: const Color(0xFF6B21A8).withAlpha(80),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
