import 'package:flutter/material.dart';

/// Ek global function jisko tum kahin se bhi call kar sakte ho.
/// Ye ek Future<bool> return karega (Positive button pe 'true', Negative/Dismiss pe 'false').
Future<bool> showCustomConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String positiveBtnText = "OK",
      String negativeBtnText = "Cancel",
      Color positiveBtnColor = Colors.blueAccent,
      Color negativeBtnBorderColor = Colors.grey,
      Color backgroundColor = const Color(0xFF2C2C2C),
    }) async {
  bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: backgroundColor,
      // 🚨 FIX 1: Title ke neeche Divider add kiya Column ka use karke
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12), // Text aur divider ke beech thoda gap
          const Divider(color: Colors.white24, thickness: 1, height: 1), // Divider line
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        // Negative Button (Outlined - Default)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: negativeBtnBorderColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, false),
          child: Text(negativeBtnText, style: const TextStyle(color: Colors.white70)),
        ),

        // 🚨 FIX 2: Positive Button ab Outlined hai (Sirf text aur border color hoga)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: positiveBtnColor, width: 1.5), // Colored Border
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            positiveBtnText,
            style: TextStyle(color: positiveBtnColor, fontWeight: FontWeight.bold), // Colored Text
          ),
        ),
      ],
    ),
  );

  // Agar user ne bahar click karke dismiss kiya (null), toh default 'false' return hoga
  return result ?? false;
}