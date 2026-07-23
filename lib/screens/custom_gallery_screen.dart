import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
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
    if (_selectedAssets.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
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
    return GestureDetector(
      onTap: _showAlbumListModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedAlbum?.name == "Recent" ? "Recent" : (_selectedAlbum?.name ?? "Albums"),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Color(0xFF999999), shape: BoxShape.circle),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF151515), size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumListModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Top ka chhota sa handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 10),
              // Main Albums ki list
              Expanded(
                child: ListView.separated(
                  itemCount: _albums.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
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
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: firstAsset != null
                                    ? _AssetThumbnail(asset: firstAsset)
                                    : const Icon(Icons.photo_album, color: Colors.white54),
                              ),

                              title: Text(
                                "${album.name == "Recent" ? "Recent" : album.name} ($count)",
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                              onTap: () {
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
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        centerTitle: true,
        title: _albums.isEmpty ? const SizedBox() : _buildAlbumSelectorButton(),

        actions: [
          // TOP RIGHT CORNER: Confirm Tick mark
          IconButton(
            icon: Icon(Icons.check, color: _selectedAssets.isNotEmpty ? Colors.blueAccent : Colors.grey, size: 28),
            onPressed: _selectedAssets.isNotEmpty ? _completeSelection : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
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
                            border: Border.all(color: Colors.blueAccent, width: 3),
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
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: SafeArea(
          child: GestureDetector(
            onTap: _openNativePicker,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                //Icon(Icons.photo_library_outlined, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  "Show all photos...",
                  style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.w500),
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
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(color: Colors.grey.shade900); // Placeholder
      },
    );
  }
}
