import 'package:flutter/material.dart';

class SocialAppShortcuts extends StatelessWidget {
  const SocialAppShortcuts({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _SocialShortcut(
        label: 'Threads',
        color: const Color(0xFF171717),
        icon: Icons.alternate_email,
        onTap: () => onOpen('threads'),
      ),
      const SizedBox(width: 24),
      _SocialShortcut(
        label: 'Instagram',
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFFCAF45)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        icon: Icons.camera_alt_outlined,
        onTap: () => onOpen('instagram'),
      ),
    ],
  );
}

class _SocialShortcut extends StatelessWidget {
  const _SocialShortcut({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    ),
  );
}
