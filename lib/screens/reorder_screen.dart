import 'dart:io';
import 'package:flutter/material.dart';

class ReorderScreen extends StatefulWidget {
  final List<Map<String, dynamic>> imageFiles;

  const ReorderScreen({Key? key, required this.imageFiles}) : super(key: key);

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.imageFiles);
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 FIX: Screen ki width ke hisab se perfect Box Size calculate kiya hai
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 32 - 20) / 2; // 2 columns, padding aur spacing hata ke
    final cellHeight = cellWidth / 0.65; // childAspectRatio 0.65 hai

    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151515),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.pop(context); // Cancel
          },
        ),
        title: const Text(
          "Reorder",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 30),
            onPressed: () {
              Navigator.pop(context, _items); // Save naya order
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: GridView.builder(
          itemCount: _items.length,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 30,
            crossAxisSpacing: 20,
            childAspectRatio: 0.65,
          ),
          itemBuilder: (context, index) {
            final currentItem = _items[index];

            return DragTarget<Map<String, dynamic>>(
              onWillAccept: (draggedItem) => draggedItem != null && draggedItem != currentItem,
              onAccept: (draggedItem) {
                final fromIndex = _items.indexOf(draggedItem);
                if (fromIndex != -1) {
                  setState(() {
                    final item = _items.removeAt(fromIndex);
                    _items.insert(index, item);
                  });
                }
              },
              builder: (context, candidateData, rejectedData) {
                bool isTargeted = candidateData.isNotEmpty;

                return LongPressDraggable<Map<String, dynamic>>(
                  data: currentItem,
                  delay: const Duration(milliseconds: 150),

                  // 🚨 FIX: Halka sa vibration hoga hold karne par
                  hapticFeedbackOnStart: true,

                  // 🚨 FIX: Hawa me tairne wali photo ko EXCACT width aur height de di taaki crash na ho
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: cellWidth,
                      height: cellHeight, // YEH LINE MISSING THI ISLIYE DRAG NAHI HO RAHA THA
                      child: Transform.scale(
                        scale: 1.05,
                        child: _buildGridItem(currentItem, index, isDragging: true),
                      ),
                    ),
                  ),

                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildGridItem(currentItem, index),
                  ),

                  child: Container(
                    decoration: isTargeted
                        ? BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 3.0),
                      borderRadius: BorderRadius.circular(6),
                    )
                        : const BoxDecoration(
                      border: Border.fromBorderSide(BorderSide(color: Colors.transparent, width: 3.0)),
                    ),
                    child: _buildGridItem(currentItem, index),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item, int index, {bool isDragging = false}) {
    File imageFile = item['cropped'] as File;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
              boxShadow: isDragging
                  ? [const BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: 3)]
                  : [const BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                imageFile,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${index + 1}",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}