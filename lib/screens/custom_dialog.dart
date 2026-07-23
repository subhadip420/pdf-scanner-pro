import 'package:flutter/material.dart';

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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, thickness: 1, height: 1),
        ],
      ),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: negativeBtnBorderColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, false),
          child: Text(negativeBtnText, style: const TextStyle(color: Colors.white70)),
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
    ),
  );
  return result ?? false;
}
