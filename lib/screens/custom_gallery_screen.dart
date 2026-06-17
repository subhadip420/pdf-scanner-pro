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
  // Naye variables dropdown ke liye
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

  // // 1. Saare folders/albums fetch karne ka logic
  // Future<void> _fetchAlbums() async {
  //   final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
  //   if (albums.isNotEmpty) {
  //     setState(() {
  //       _albums = albums;
  //       _selectedAlbum = albums.first; // Default 'Recent' album select hoga
  //     });
  //     _fetchAssetsFromAlbum(_selectedAlbum!);
  //   } else {
  //     setState(() => _isLoading = false);
  //   }
  // }

  // 1. Saare folders/albums fetch karne ka logic (With Naye Photos First Sorting)
  Future<void> _fetchAlbums() async {
    // 🚨 FIX: Yahan filter laga diya taaki strictly Naye Photos Top par aayein
    final FilterOptionGroup filterOption = FilterOptionGroup(
      orders: [
        const OrderOption(
          type: OrderOptionType.createDate,
          asc: false, // asc: false ka matlab hai 'Newest First' (Naya pehle, Purana baad me)
        ),
      ],
    );

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: filterOption, // Naya filter pass kar diya
    );

    if (albums.isNotEmpty) {
      setState(() {
        _albums = albums;
        _selectedAlbum = albums.first; // Default 'Recent' album select hoga
      });
      _fetchAssetsFromAlbum(_selectedAlbum!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 2. Selected album ke andar ki photos laane ka logic
  Future<void> _fetchAssetsFromAlbum(AssetPathEntity album) async {
    setState(() => _isLoading = true);
    // 100 photos initially load kar rahe hain speed fast rakhne ke liye
    final List<AssetEntity> assets = await album.getAssetListPaged(page: 0, size: 100);
    setState(() {
      _assets = assets;
      _isLoading = false;
    });
  }

  // Top right corner se Confirm (Tic) karne ka logic
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
      Navigator.pop(context); // Loading hatao
      Navigator.pop(context, files); // Files ko pichli screen par bhejo
    }
  }

  // "Show all photos..." par click karke Android System Picker kholna
  Future<void> _openNativePicker() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      List<File> files = images.map((x) => File(x.path)).toList();
      if (mounted) Navigator.pop(context, files); // Direct scanner me bhej do
    }
  }

  // 1. Naya Top 'Recent' Button ka design (Screenshot 1 jaisa)
  Widget _buildAlbumSelectorButton() {
    return GestureDetector(
      onTap: _showAlbumListModal, // Click karne par list khulegi
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF333333), // Dark grey pill background
          borderRadius: BorderRadius.circular(24),
        ),
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
              decoration: const BoxDecoration(
                color: Color(0xFF999999), // Light grey circle
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF151515), size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Click karne par Album List kholne ka design (Screenshot 2 jaisa)
  // void _showAlbumListModal() {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: const Color(0xFF1E1E1E), // Dark theme
  //     isScrollControlled: true, // Screen height control karne ke liye
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Upar se round
  //     ),
  //     builder: (BuildContext context) {
  //       return SizedBox(
  //         height: MediaQuery.of(context).size.height * 0.75, // Screen ka 75% height lega
  //         child: Column(
  //           children: [
  //             const SizedBox(height: 10),
  //             // Top ka chhota sa handle bar
  //             Container(
  //               width: 40,
  //               height: 4,
  //               decoration: BoxDecoration(
  //                 color: Colors.grey.shade600,
  //                 borderRadius: BorderRadius.circular(2),
  //               ),
  //             ),
  //             const SizedBox(height: 10),
  //             // Main Albums ki list
  //             Expanded(
  //               child: ListView.separated(
  //                 itemCount: _albums.length,
  //                 separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
  //                 itemBuilder: (context, index) {
  //                   final album = _albums[index];
  //                   final isSelected = album == _selectedAlbum;
  //
  //                   // Photo count laane ke liye FutureBuilder
  //                   return FutureBuilder<int>(
  //                     future: album.assetCountAsync,
  //                     builder: (context, snapshot) {
  //                       final count = snapshot.data ?? 0;
  //                       return ListTile(
  //                         contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
  //                         title: Text(
  //                           "${album.name == "Recent" ? "Recent" : album.name} ($count)",
  //                           style: const TextStyle(color: Colors.white, fontSize: 16),
  //                         ),
  //                         // Agar select hai toh Green Tick dikhao
  //                         trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
  //                         onTap: () {
  //                           Navigator.pop(context); // List close karo
  //                           if (!isSelected) {
  //                             setState(() {
  //                               _selectedAlbum = album; // Naya album set karo
  //                             });
  //                             _fetchAssetsFromAlbum(album); // Nayi photos load karo
  //                           }
  //                         },
  //                       );
  //                     },
  //                   );
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // 2. Click karne par Album List kholne ka design (With Thumbnails)
  void _showAlbumListModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E), // Dark theme
      isScrollControlled: true, // Screen height control karne ke liye
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Upar se round
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75, // Screen ka 75% height lega
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Top ka chhota sa handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
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

                    // 🚨 NEW: Album ki pehli photo (cover) laane ke liye FutureBuilder
                    return FutureBuilder<List<AssetEntity>>(
                      future: album.getAssetListPaged(page: 0, size: 1), // Sirf 1 photo fetch karenge cover ke liye
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

                              // 🚨 NEW: Leading Thumbnail Image
                              leading: Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(4), // Halka sa rounded corner
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: firstAsset != null
                                    ? _AssetThumbnail(asset: firstAsset) // Apni flicker-free class use ki
                                    : const Icon(Icons.photo_album, color: Colors.white54), // Agar folder khali ho
                              ),

                              title: Text(
                                "${album.name == "Recent" ? "Recent" : album.name} ($count)",
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              // Agar select hai toh Green Tick dikhao
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                              onTap: () {
                                Navigator.pop(context); // List close karo
                                if (!isSelected) {
                                  setState(() {
                                    _selectedAlbum = album; // Naya album set karo
                                  });
                                  _fetchAssetsFromAlbum(album); // Nayi photos load karo
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
      // appBar: AppBar(
      //   backgroundColor: const Color(0xFF1E1E1E),
      //   elevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.close, color: Colors.white),
      //     onPressed: () => Navigator.pop(context),
      //   ),
      //
      //   // 🚨 UPDATE: "Add from photos" hata kar Album Dropdown laga diya 🚨
      //   title: _albums.isEmpty
      //       ? const SizedBox()
      //       : DropdownButtonHideUnderline(
      //     child: DropdownButton<AssetPathEntity>(
      //       value: _selectedAlbum,
      //       dropdownColor: const Color(0xFF2C2C2C),
      //       icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
      //       style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      //       onChanged: (AssetPathEntity? newAlbum) {
      //         if (newAlbum != null && newAlbum != _selectedAlbum) {
      //           setState(() {
      //             _selectedAlbum = newAlbum;
      //           });
      //           _fetchAssetsFromAlbum(newAlbum); // Naya folder select hote hi photos change hongi
      //         }
      //       },
      //       items: _albums.map((AssetPathEntity album) {
      //         return DropdownMenuItem<AssetPathEntity>(
      //           value: album,
      //           child: Text(album.name == "Recent" ? "Recents" : album.name),
      //         );
      //       }).toList(),
      //     ),
      //   ),
      //
      //   actions: [
      //     // TOP RIGHT CORNER: Confirm Tick mark
      //     IconButton(
      //       icon: Icon(
      //         Icons.check,
      //         color: _selectedAssets.isNotEmpty ? Colors.blueAccent : Colors.grey,
      //         size: 28,
      //       ),
      //       onPressed: _selectedAssets.isNotEmpty ? _completeSelection : null,
      //     )
      //   ],
      // ),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        centerTitle: true, // Button ko exactly center me laane ke liye

        // 🚨 Naya Custom Button Call 🚨
        title: _albums.isEmpty ? const SizedBox() : _buildAlbumSelectorButton(),

        actions: [
          // TOP RIGHT CORNER: Confirm Tick mark
          IconButton(
            icon: Icon(
              Icons.check,
              color: _selectedAssets.isNotEmpty ? Colors.blueAccent : Colors.grey,
              size: 28,
            ),
            onPressed: _selectedAssets.isNotEmpty ? _completeSelection : null,
          )
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
            // Photo par KAHI BHI tap karne se select/deselect hoga
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedAssets.remove(asset);
                } else {
                  _selectedAssets.add(asset);
                }
              });
            },
            // child: Stack(
            //   fit: StackFit.expand,
            //   children: [
            //     // Image Thumbnail load karna
            //     FutureBuilder<Uint8List?>(
            //       future: asset.thumbnailDataWithSize(const ThumbnailSize.square(250)),
            //       builder: (_, snapshot) {
            //         if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            //           return Image.memory(snapshot.data!, fit: BoxFit.cover);
            //         }
            //         return Container(color: Colors.grey.shade900); // Placeholder
            //       },
            //     ),
            //
            //     // SELECTED PHOTO PAR BLUE BORDER aur halka blackish overlay
            //     if (isSelected)
            //       Container(
            //         decoration: BoxDecoration(
            //           color: Colors.black.withOpacity(0.3),
            //           border: Border.all(color: Colors.blueAccent, width: 3),
            //         ),
            //       ),
            //
            //     // SELECTED PHOTO MEIN SIRF NUMBER (Blue Circle mein)
            //     if (isSelected)
            //       Positioned(
            //         top: 6,
            //         left: 6,
            //         child: Container(
            //           width: 24,
            //           height: 24,
            //           decoration: const BoxDecoration(
            //             color: Colors.blueAccent,
            //             shape: BoxShape.circle,
            //           ),
            //           alignment: Alignment.center,
            //           child: Text(
            //             '$selectedIndex',
            //             style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            //           ),
            //         ),
            //       )
            //   ],
            // ),

            child: Stack(
              fit: StackFit.expand,
              children: [
                // 🚨 FIX: Purana FutureBuilder hata kar naya stable widget lagaya
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
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$selectedIndex',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
          );
        },
      ),

      // BOTTOM BAR: "Show all photos..." ka option
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
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Ekdum solid aur stable thumbnail widget jo flicker nahi karega
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
    // Image data sirf ek baar load hoga jab widget pehli baar banega
    _future = widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(250));
  }

  @override
  void didUpdateWidget(covariant _AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Agar scroll karne par naya asset aata hai, tabhi data wapas load hoga
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