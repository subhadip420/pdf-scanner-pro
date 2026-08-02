import 'package:flutter/material.dart';

class CustomToast {
  static void show(
      BuildContext context, {
        required String message,
        IconData? icon,
        Color? backgroundColor,
        Color? textColor,
        Color? iconColor,
        Duration duration = const Duration(seconds: 3),
      }) {
    // Current theme check karna (Dark ya Light)
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Default colors agar user custom color pass na kare
    final defaultBgColor = isDarkMode ? const Color(0xFF333333) : const Color(0xFF2D2D2D);
    final defaultTextColor = isDarkMode ? Colors.white : Colors.white;

    // Pehle se koi snackbar open ho toh use hide kar do
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16,16,16,80),
        backgroundColor: backgroundColor ?? defaultBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
        content: Row(
          children: [
            // Agar icon pass kiya hai tabhi dikhayega
            if (icon != null) ...[
              Icon(
                icon,
                color: iconColor ?? (isDarkMode ? Colors.white70 : Colors.white70),
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            // Text hamesha Expanded mein taaki overflow na ho
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor ?? defaultTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2, // Maximum 2 lines tak dikhayega
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}