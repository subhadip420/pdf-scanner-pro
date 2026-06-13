import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DocumentEditorScreen extends StatefulWidget {
  final List<File> imageFiles; // Real images coming from ScannerScreen

  const DocumentEditorScreen({super.key, required this.imageFiles});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late String documentName;
  late PageController _pageController;
  int currentPage = 0;
  bool isThumbnailVisible = true; // By default thumbnails dikhenge


  @override
  void initState() {
    super.initState();
    documentName = _generateDefaultName();
    // Open the latest captured photo first
    currentPage = widget.imageFiles.length - 1;
    _pageController = PageController(initialPage: currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Generate default file name based on current date
  String _generateDefaultName() {
    final now = DateTime.now();
    final months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "Adobe Scan ${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  // Show toast notification
  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.white,
      textColor: Colors.black,
    );
  }

  // Go to previous page
  void _previousPage() {
    if (currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      showToast("First page");
    }
  }

  // Go to next page
  void _nextPage() {
    if (currentPage < widget.imageFiles.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      showToast("Last page");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,

        /// Left Icon (Home)
        leading: Tooltip(
          message: "Home",
          child: IconButton(
            icon: const Icon(Icons.home, color: Colors.white, size: 28),
            onPressed: () {
              showToast("Home tapped");
            },
          ),
        ),

        /// Middle: Clickable Auto-generated Name
        title: Tooltip(
          message: "Rename document",
          child: GestureDetector(
            onTap: () {
              showToast("Rename document tapped");
            },
            child: Text(
              documentName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: Colors.white54,
              ),
            ),
          ),
        ),
        centerTitle: true,

        /// Right Icon
        actions: [
          Tooltip(
            message: "Document Options",
            child: IconButton(
              icon: const Icon(Icons.edit_document, color: Colors.white, size: 24),
              onPressed: () {
                showToast("Options tapped");
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          /// MAIN PREVIEW AREA
          Expanded(
            child: Stack(
              children: [
                // Swipeable & Zoomable Images
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemCount: widget.imageFiles.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Container(
                        margin: const EdgeInsets.only(left: 30, right: 30, top: 20, bottom: 80),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.white24, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              )
                            ]
                        ),
                        child: Image.file(
                          widget.imageFiles[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),

                // Overlay Controls (Arrows and Page Count)
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// Left Arrow
                      Tooltip(
                        message: "Previous Page",
                        child: GestureDetector(
                          onTap: _previousPage,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18
                            ),
                          ),
                        ),
                      ),

                      /// Middle Controls (Add Icon + Page Count)
                      Row(
                        children: [
                          Tooltip(
                            message: "Add New Page",
                            child: GestureDetector(
                              onTap: () => showToast("Add new page"),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.post_add_rounded,
                                    color: Colors.white,
                                    size: 20
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Tooltip(
                            message: "Jump to page",
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isThumbnailVisible = !isThumbnailVisible;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      "Page ${currentPage + 1} of ${widget.imageFiles.length}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                        size: 18
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      /// Right Arrow
                      Tooltip(
                        message: "Next Page",
                        child: GestureDetector(
                          onTap: _nextPage,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 18
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// BOTTOM HORIZONTAL THUMBNAIL LIST
          if (isThumbnailVisible)
            Container(
              height: 90,
              color: const Color(0xFF1E1E1E),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.imageFiles.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemBuilder: (context, index) {
                  bool isSelected = currentPage == index;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(widget.imageFiles[index]),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 20,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          /// NEW ACTION TOOLS BAR (Horizontal Scrollable)
          Container(
            height: 85,
            color: const Color(0xFF151515), // Dark background for tools section
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _buildToolItem(label: "Retake", icon: Icons.refresh_rounded, tooltipMessage: "Retake current photo"),
                _buildToolItem(label: "Crop", icon: Icons.crop_rounded, tooltipMessage: "Crop & adjust borders"),
                _buildToolItem(label: "Rotate", icon: Icons.rotate_right_rounded, tooltipMessage: "Rotate 90 degrees"),
                _buildToolItem(label: "Filter", icon: Icons.photo_filter_rounded, tooltipMessage: "Apply color filters"),
                _buildToolItem(label: "Adjust", icon: Icons.tune_rounded, tooltipMessage: "Adjust brightness and contrast"),
                _buildToolItem(label: "Markup", icon: Icons.border_color_rounded, tooltipMessage: "Draw or add text on image"),
                _buildToolItem(label: "Cleanup", icon: Icons.auto_fix_high_rounded, tooltipMessage: "Erase unwanted areas"),
                _buildToolItem(label: "Resize", icon: Icons.aspect_ratio_rounded, tooltipMessage: "Change page layout size"),
                _buildToolItem(label: "Reorder", icon: Icons.swap_horizontal_circle_outlined, tooltipMessage: "Rearrange page sequence"),
                _buildToolItem(label: "Delete", icon: Icons.delete_outline_rounded, tooltipMessage: "Delete current page"),
              ],
            ),
          ),

          /// NAYA BOTTOM BAR: Keep Scanning & Save PDF
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black, // Ekdum dark background
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Keep Scanning Text Button
                  TextButton(
                    onPressed: () {
                      showToast("Keep scanning");
                      Navigator.pop(context); // Wapas camera par le jayega
                    },
                    child: const Text(
                      "Keep scanning",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Save PDF Button
                  ElevatedButton(
                    onPressed: () => showToast("Save PDF clicked"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, // Adobe scan jaisa blue
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text("Save PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }


  // Helper widget to build action tools with icon, text, tooltip, and toast
  Widget _buildToolItem({
    required String label,
    required IconData icon,
    required String tooltipMessage
  }) {
    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: () => showToast("$label clicked"), // Placeholder toast
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}/// end main class