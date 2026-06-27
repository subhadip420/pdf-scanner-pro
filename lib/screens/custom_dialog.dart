import 'package:flutter/material.dart';

/// Ek global function jisko aap kahin se bhi call kar sakte ho.
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
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        // Negative Button (Outlined)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: negativeBtnBorderColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, false),
          child: Text(negativeBtnText, style: const TextStyle(color: Colors.white70)),
        ),

        // Positive Button (Elevated)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: positiveBtnColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(positiveBtnText, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  // Agar user ne bahar click karke dismiss kiya (null), toh default 'false' return hoga
  return result ?? false;
}