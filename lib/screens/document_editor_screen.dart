import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io'; // File use karne ke liye zaroori hai
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';


class DocumentEditorScreen extends StatefulWidget {
  final List<File> imageFiles; // Scanner se aane wali images

  const DocumentEditorScreen({super.key, required this.imageFiles});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late String documentName;
  late PageController _pageController;

  // // Dummy data for testing (Later replaced with actual images)
  // final List<Color> dummyPages = [
  //   Colors.grey.shade800,
  //   Colors.blueGrey.shade800,
  //   Colors.brown.shade800,
  //   Colors.teal.shade800,
  // ];

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    documentName = _generateDefaultName();

    // Latest photo ko sabse pehle dikhane ke liye index set kiya
    currentPage = widget.imageFiles.length - 1;
    _pageController = PageController(initialPage: currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Generate default file name
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
    // Yahan humne dummyPages ko widget.imageFiles se replace kar diya hai
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
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme background
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
                  itemCount: widget.imageFiles.length, // Dummy hata kar real length
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Container(
                        margin: const EdgeInsets.only(left: 30, right: 30, top: 20, bottom: 80),
                        decoration: BoxDecoration(
                            color: Colors.black, // Background color
                            border: Border.all(color: Colors.white24, width: 1),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                            ]
                        ),
                        // REAL IMAGE YAHAN AAYEGI
                        child: Image.file(
                          widget.imageFiles[index],
                          fit: BoxFit.contain, // Taaki puri photo fit ho jaye
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
                              onTap: () => showToast("Open page grid"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    // Yahan dummyPages ko widget.imageFiles se replace kiya hai
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
          Container(
            height: 90,
            color: const Color(0xFF1E1E1E), // Slightly darker background for the strip
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.imageFiles.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemBuilder: (context, index) {

                // Check if this thumbnail is the currently selected page
                bool isSelected = currentPage == index;

                return GestureDetector(
                  onTap: () {
                    // Clicking thumbnail slides the main preview to this page
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
                      // BACKGROUND ME REAL CHHOTI IMAGE
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
                        // Small dark gradient at bottom so the white text is readable
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

                        // Sequence Number (1, 2, 3...)
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

          /// RESERVED SPACE FOR ACTION TOOLS (Crop, Rotate, Save)
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}