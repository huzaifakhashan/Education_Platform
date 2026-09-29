import 'package:flutter/material.dart';

import '../models/profile.dart';

/// App logo drawn in code (matches the launcher icon).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.white, size: size * 0.6),
          Positioned(
            top: size * 0.14,
            right: size * 0.14,
            child: Icon(Icons.auto_awesome, color: const Color(0xFFFDE047), size: size * 0.2),
          ),
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 8});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: color ?? Theme.of(context).colorScheme.primary,
        backgroundColor: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
      ),
    );
  }
}

/// Surface color for cards: white in light mode, elevated surface in dark.
Color cardColor(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return scheme.brightness == Brightness.dark ? scheme.surfaceContainerHigh : Colors.white;
}

/// Small colored pill.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.dropdown = false});

  final String text;
  final Color color;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 12, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          if (dropdown) Icon(Icons.arrow_drop_down, size: 18, color: color),
        ],
      ),
    );
  }
}

/// Pill showing a user's role.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, this.label, this.dropdown = false});

  final UserRole role;
  final String? label;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => Colors.red.shade400,
      UserRole.teacher => Colors.teal.shade500,
      UserRole.student => Colors.indigo.shade400,
    };
    return Pill(text: label ?? role.label, color: color, dropdown: dropdown);
  }
}
