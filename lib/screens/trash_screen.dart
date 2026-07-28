import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'custom_dialog.dart'; // Tumhara custom dialog import

class TrashScreen extends StatefulWidget {
  const TrashScreen({Key? key}) : super(key: key);

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<File> _trashFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrashFiles();
  }

  // --- 1. LOAD TRASH FILES ---
  Future<void> _loadTrashFiles() async {
    setState(() => _isLoading = true);
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory trashDir = Directory('${appDir.path}/.trash');

      if (await trashDir.exists()) {
        // Sirf PDF files lo aur Last Modified time ke hisaab se sort karo (Newest First)
        List<File> files = trashDir
            .listSync()
            .where((entity) => entity is File && entity.path.endsWith('.pdf'))
            .map((entity) => File(entity.path))
            .toList();

        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _trashFiles = files;
        });
      } else {
        setState(() {
          _trashFiles = [];
        });
      }
    } catch (e) {
      print("Error loading trash: $e");
    }
    setState(() => _isLoading = false);
  }

  // --- 2. RESTORE FILE ---
  Future<void> _restoreFile(File trashFile) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      String fileName = trashFile.path.split('/').last;
      String restorePath = '${appDir.path}/$fileName';
      File restoredFile = File(restorePath);

      // Agar same naam ki file Home mein pehle se hai toh rename karo
      int counter = 1;
      while (await restoredFile.exists()) {
        String nameWithoutExt = fileName.replaceAll('.pdf', '');
        restorePath = '${appDir.path}/$nameWithoutExt ($counter).pdf';
        restoredFile = File(restorePath);
        counter++;
      }

      await trashFile.copy(restoredFile.path); // Copy to Home
      await trashFile.delete(); // Delete from Trash

      Fluttertoast.showToast(msg: "File Restored");
      _loadTrashFiles(); // List update karo
    } catch (e) {
      Fluttertoast.showToast(msg: "Error restoring file");
    }
  }

  // --- 3. PERMANENTLY DELETE SINGLE FILE ---
  Future<void> _deleteForever(File trashFile) async {
    bool confirm = await showCustomConfirmDialog(
      context,
      title: "Delete Forever",
      message: "Are you sure you want to permanently delete this file? This action cannot be undone.",
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (confirm) {
      try {
        await trashFile.delete();
        Fluttertoast.showToast(msg: "Deleted permanently");
        _loadTrashFiles();
      } catch (e) {
        Fluttertoast.showToast(msg: "Error deleting file");
      }
    }
  }

  // --- 4. EMPTY TRASH (DELETE ALL) ---
  Future<void> _emptyTrash() async {
    if (_trashFiles.isEmpty) return;

    bool confirm = await showCustomConfirmDialog(
      context,
      title: "Empty Trash",
      message: "Are you sure you want to permanently delete all files in the trash?",
      positiveBtnText: "Empty Trash",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        for (File file in _trashFiles) {
          await file.delete();
        }
        Fluttertoast.showToast(msg: "Trash Emptied");
        _loadTrashFiles();
      } catch (e) {
        Fluttertoast.showToast(msg: "Error emptying trash");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF1F0F0),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        title: Text("Recently Deleted", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black,),
        actions: [
          if (_trashFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0), // Value ko apne hisaab se adjust kar sakte ho
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                tooltip: "Empty Trash",
                onPressed: _emptyTrash,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.blueAccent : Colors.blue))
          : _trashFiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.recycling_rounded, size: 80, color: isDarkMode ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text("Trash is empty", style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white54 : Colors.black54)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _trashFiles.length,
        itemBuilder: (context, index) {
          File file = _trashFiles[index];
          String fileName = file.path.split('/').last;

          // Days remaining logic calculate karna
          DateTime deleteDate = file.lastModifiedSync();
          int daysElapsed = DateTime.now().difference(deleteDate).inDays;
          int daysLeft = 30 - daysElapsed;
          if (daysLeft < 0) daysLeft = 0; // Negative se bachne ke liye

          return Card(
            color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () {
                OpenFile.open(file.path);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
              ),
              title: Text(
                fileName,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  daysLeft == 0
                      ? "Will be deleted today"
                      : "$daysLeft days left",
                  style: TextStyle(
                    color: daysLeft <= 3
                        ? (isDarkMode ? Colors.redAccent : Colors.red)
                        : (isDarkMode ? Colors.orangeAccent : Colors.orange.shade800),
                    fontSize: 12,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: "Restore",
                    child: IconButton(
                      icon: Icon(Icons.restore_rounded, color: isDarkMode ? Colors.blueAccent : Colors.blue.shade700,),
                      onPressed: () => _restoreFile(file),
                    ),
                  ),
                  Tooltip(
                    message: "Delete Permanently",
                    child: IconButton(
                      icon: Icon(Icons.delete_forever_rounded, color: isDarkMode ? Colors.white54 : Colors.black54,),
                      onPressed: () => _deleteForever(file),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}