import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomGalleryScreen extends StatefulWidget {
  const CustomGalleryScreen({Key? key}) : super(key: key);

  @override
  State<CustomGalleryScreen> createState() => _CustomGalleryScreenState();
}

class _CustomGalleryScreenState extends State<CustomGalleryScreen> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;

  List<AssetEntity> _assets = [];
  List<AssetEntity> _selectedAssets = [];
  bool _isLoading = true;
  bool isHapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
    _loadHapticSetting();
  }

  Future<void> _loadHapticSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isHapticEnabled = prefs.getBool('pref_haptic') ?? true;
    });
  }

  Future<void> _fetchAlbums() async {
    final FilterOptionGroup filterOption = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: filterOption,
    );

    if (albums.isNotEmpty) {
      setState(() {
        _albums = albums;
        _selectedAlbum = albums.first;
      });
      _fetchAssetsFromAlbum(_selectedAlbum!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAssetsFromAlbum(AssetPathEntity album) async {
    setState(() => _isLoading = true);
    final List<AssetEntity> assets = await album.getAssetListPaged(page: 0, size: 100);
    setState(() {
      _assets = assets;
      _isLoading = false;
    });
  }

  void _completeSelection() async {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_selectedAssets.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.blueAccent : Colors.blue)),
    );

    List<File> files = [];
    for (var asset in _selectedAssets) {
      final File? file = await asset.file;
      if (file != null) files.add(file);
    }

    if (mounted) {
      Navigator.pop(context);
      Navigator.pop(context, files);
    }
  }

  Future<void> _openNativePicker() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      List<File> files = images.map((x) => File(x.path)).toList();
      if (mounted) Navigator.pop(context, files);
    }
  }

  Widget _buildAlbumSelectorButton() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (isHapticEnabled) HapticFeedback.lightImpact();
        _showAlbumListModal();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF333333) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedAlbum?.name == "Recent" ? "Recent" : (_selectedAlbum?.name ?? "Albums"),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF999999) : Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDarkMode ? const Color(0xFF151515) : Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumListModal() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              // Main Albums ki list
              Expanded(
                child: ListView.separated(
                  itemCount: _albums.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: isDarkMode ? Colors.white12 : Colors.black26, height: 1),
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    final isSelected = album == _selectedAlbum;

                    return FutureBuilder<List<AssetEntity>>(
                      future: album.getAssetListPaged(page: 0, size: 1),
                      builder: (context, assetSnapshot) {
                        final firstAsset = (assetSnapshot.hasData && assetSnapshot.data!.isNotEmpty)
                            ? assetSnapshot.data!.first
                            : null;

                        return FutureBuilder<int>(
                          future: album.assetCountAsync,
                          builder: (context, countSnapshot) {
                            final count = countSnapshot.data ?? 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: firstAsset != null
                                    ? _AssetThumbnail(asset: firstAsset)
                                    : const Icon(Icons.photo_album, color: Colors.white54),
                              ),

                              title: Text(
                                "${album.name == "Recent" ? "Recent" : album.name} ($count)",
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
                              ),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                              onTap: () {
                                if (isHapticEnabled) HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                if (!isSelected) {
                                  setState(() {
                                    _selectedAlbum = album;
                                  });
                                  _fetchAssetsFromAlbum(album);
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade300,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () {
            if (isHapticEnabled) HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),

        centerTitle: true,
        title: _albums.isEmpty ? const SizedBox() : _buildAlbumSelectorButton(),

        actions: [
          IconButton(
            icon: Icon(
              Icons.check,
              color: _selectedAssets.isNotEmpty
                  ? (isDarkMode ? Colors.blueAccent : Colors.blue)
                  : Colors.grey,
              size: 28,
            ),
            onPressed: _selectedAssets.isNotEmpty
                ? () {
              if (isHapticEnabled) HapticFeedback.lightImpact();
              _completeSelection();
            }
                : null,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.blueAccent : Colors.blue))
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                final isSelected = _selectedAssets.contains(asset);
                final selectedIndex = _selectedAssets.indexOf(asset) + 1;

                return GestureDetector(
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() {
                      if (isSelected) {
                        _selectedAssets.remove(asset);
                      } else {
                        _selectedAssets.add(asset);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AssetThumbnail(asset: asset),

                      // SELECTED PHOTO PAR BLUE BORDER aur halka blackish overlay
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            border: Border.all(color: isDarkMode ? Colors.blueAccent : Colors.blue, width: 3),
                          ),
                        ),

                      // SELECTED PHOTO MEIN SIRF NUMBER (Blue Circle mein)
                      if (isSelected)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(
                              '$selectedIndex',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

      /// BOTTOM BAR: "Show all photos..." ka option
      bottomNavigationBar: Container(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: SafeArea(
          child: GestureDetector(
            //onTap: _openNativePicker,
            onTap: () {
              if (isHapticEnabled) HapticFeedback.lightImpact();
              _openNativePicker();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 8),
                Text(
                  "Show all photos...",
                  style: TextStyle(
                    color: isDarkMode ? Colors.lightBlueAccent : Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;

  const _AssetThumbnail({Key? key, required this.asset}) : super(key: key);

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(250));
  }

  @override
  void didUpdateWidget(covariant _AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _future = widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(250));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade300); // Placeholder
      },
    );
  }
}
