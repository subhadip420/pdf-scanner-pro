import 'package:flutter/material.dart';

Future<bool> showCustomConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String positiveBtnText = "OK",
  String negativeBtnText = "Cancel",
  Color positiveBtnColor = Colors.blueAccent,
  Color negativeBtnBorderColor = Colors.grey,
  Color? backgroundColor,
}) async {
  bool? result = await showDialog<bool>(
    context: context,
    builder: (context) {
      bool isDarkMode = Theme
          .of(context)
          .brightness == Brightness.dark;

      return AlertDialog(
        backgroundColor: backgroundColor ?? (isDarkMode ? const Color(0xFF2C2C2C) : Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Divider(color: isDarkMode ? Colors.white24 : Colors.black26, thickness: 1, height: 1),
          ],
        ),
        content: Text(message, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: negativeBtnBorderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(negativeBtnText, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
          ),

          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: positiveBtnColor, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              positiveBtnText,
              style: TextStyle(color: positiveBtnColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
