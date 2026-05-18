import 'dart:io';
import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'property_data.dart';

/// Represents a listing image — either from the DB (existing) or locally picked (pending upload).
class ListingImageItem {
  /// DB record ID (null for pending uploads)
  final String? id;

  /// Full URL for existing images
  final String? url;

  /// Local file for pending uploads
  final XFile? localFile;

  /// 'normal' or 'panorama'
  final String imageType;

  /// 'upload' or 'capture'
  final String uploadSource;

  final int sortOrder;
  final bool isCover;

  ListingImageItem({
    this.id,
    this.url,
    this.localFile,
    this.imageType = 'normal',
    this.uploadSource = 'upload',
    this.sortOrder = 0,
    this.isCover = false,
  });

  bool get isLocal => localFile != null;
  bool get isRemote => url != null && !isLocal;
}

/// A reusable screen for managing listing images (gallery/camera upload, reorder, delete).
/// Can be used both when creating a new listing and editing an existing one.
class ListingImageManagerScreen extends StatefulWidget {
  /// If editing an existing listing, pass the ID to load current images.
  final String? listingId;

  /// For new listings, pre-populate with locally picked images.
  final List<XFile>? initialLocalImages;

  const ListingImageManagerScreen({
    super.key,
    this.listingId,
    this.initialLocalImages,
  });

  @override
  State<ListingImageManagerScreen> createState() =>
      _ListingImageManagerScreenState();
}

class _ListingImageManagerScreenState extends State<ListingImageManagerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<ListingImageItem> _images = [];
  final PageController _pageController = PageController();

  bool _loading = true;
  bool _uploading = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);

    // Load existing images from DB
    if (widget.listingId != null) {
      final records = await fetchListingImageRecords(widget.listingId!);
      for (final rec in records) {
        if ((rec['type'] ?? 'normal') != 'normal') continue;
        _images.add(ListingImageItem(
          id: rec['id'],
          url: buildStorageUrl(rec['url'] ?? ''),
          imageType: rec['type'] ?? 'normal',
          uploadSource: rec['upload_source'] ?? 'upload',
          sortOrder: rec['sort_order'] ?? 0,
          isCover: rec['is_cover'] ?? false,
        ));
      }
    }

    // Add any initial local images
    if (widget.initialLocalImages != null) {
      for (int i = 0; i < widget.initialLocalImages!.length; i++) {
        _images.add(ListingImageItem(
          localFile: widget.initialLocalImages![i],
          sortOrder: _images.length + i,
          uploadSource: 'upload',
        ));
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Pick from Gallery ──
  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        for (final img in picked) {
          _images.add(ListingImageItem(
            localFile: img,
            sortOrder: _images.length,
            uploadSource: 'upload',
          ));
        }
      });
    }
  }

  // ── Capture from Camera ──
  Future<void> _captureFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _images.add(ListingImageItem(
          localFile: picked,
          sortOrder: _images.length,
          uploadSource: 'capture',
        ));
      });
    }
  }

  // ── Add image bottom sheet ──
  Future<void> _showAddImageSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Add Photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library, color: VxrTokens.accent),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select multiple photos'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: VxrTokens.accent),
              title: const Text('Take a Photo'),
              subtitle: const Text('Use your camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'gallery') {
      await _pickFromGallery();
    } else if (action == 'camera') {
      await _captureFromCamera();
    }
  }

  // ── Remove image ──
  Future<void> _removeImage(int index) async {
    final item = _images[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Image'),
        content: const Text('Are you sure you want to remove this image?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // If it's a remote image, delete from DB
    if (item.isRemote && item.id != null) {
      await deleteListingImage(item.id!);
    }

    setState(() {
      _images.removeAt(index);
      if (_currentPage >= _images.length && _images.isNotEmpty) {
        _currentPage = _images.length - 1;
      }
    });
  }

  // ── Set as cover ──
  void _setCover(int index) {
    setState(() {
      for (int i = 0; i < _images.length; i++) {
        _images[i] = ListingImageItem(
          id: _images[i].id,
          url: _images[i].url,
          localFile: _images[i].localFile,
          imageType: _images[i].imageType,
          uploadSource: _images[i].uploadSource,
          sortOrder: _images[i].sortOrder,
          isCover: i == index,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Set as cover photo'),
        backgroundColor: VxrTokens.accent,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ── Upload all pending images & save ──
  Future<void> _saveImages() async {
    if (widget.listingId == null) {
      // For new listings, return the local files back
      Navigator.pop(context, _images);
      return;
    }

    final pendingImages = _images.where((img) => img.isLocal).toList();
    if (pendingImages.isEmpty) {
      Navigator.pop(context, _images);
      return;
    }

    setState(() => _uploading = true);

    try {
      final storagePaths = <String>[];
      final sources = <String>[];

      for (int i = 0; i < pendingImages.length; i++) {
        final img = pendingImages[i];
        final bytes = await img.localFile!.readAsBytes();
        final ext = img.localFile!.name.split('.').last;
        final path =
            '${widget.listingId}/img_${_images.indexOf(img)}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await Supabase.instance.client.storage
            .from('listing-images')
            .uploadBinary(path, bytes);

        storagePaths.add(path);
        sources.add(img.uploadSource);
      }

      // Save to listing_images table with proper metadata
      if (storagePaths.isNotEmpty) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final existingCount =
            _images.where((img) => img.isRemote).length;

        final rows = storagePaths.asMap().entries.map((e) => {
          'listing_id': widget.listingId,
          'url': e.value,
          'type': 'normal',
          'upload_source': sources[e.key],
          'sort_order': existingCount + e.key,
          'is_cover': false,
          'uploaded_by': userId,
        }).toList();

        await Supabase.instance.client.from('listing_image').insert(rows);
      }

      // Update cover photo if changed.
      // Build a map from the index in pendingImages → uploaded storagePath
      // so we can resolve the correct URL for newly-uploaded cover items.
      final uploadedPathByPendingIndex = <int, String>{};
      for (int i = 0; i < pendingImages.length; i++) {
        if (i < storagePaths.length) {
          uploadedPathByPendingIndex[i] = storagePaths[i];
        }
      }

      final coverItem = _images.firstWhere(
        (img) => img.isCover,
        orElse: () => _images.first,
      );

      String? coverUrlToSave;
      if (coverItem.isRemote && coverItem.url != null) {
        // Already-uploaded image — use its public URL as the raw path or full URL.
        // The DB stores the storage path; extract it from the full URL if needed.
        coverUrlToSave = coverItem.url;
      } else if (coverItem.isLocal) {
        // Newly uploaded — find the storage path we just saved.
        final idx = pendingImages.indexOf(coverItem);
        if (idx >= 0 && idx < storagePaths.length) {
          coverUrlToSave = storagePaths[idx];
        } else if (storagePaths.isNotEmpty) {
          // Fallback: use the first newly-uploaded path.
          coverUrlToSave = storagePaths.first;
        }
      }

      if (coverUrlToSave != null) {
        await Supabase.instance.client
            .from('listings')
            .update({'cover_photo_url': coverUrlToSave})
            .eq('id', widget.listingId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Images saved successfully'),
            backgroundColor: VxrTokens.accent,
          ),
        );
        Navigator.pop(context, _images);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VxrTokens.bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        title: const Text(
          'Manage Photos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_images.any((img) => img.isLocal))
            TextButton(
              onPressed: _uploading ? null : _saveImages,
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VxrTokens.accent),
            )
          : Column(
              children: [
                // ── PageView Image Preview ──
                _buildImagePreview(),

                // ── Thumbnail Strip ──
                _buildThumbnailStrip(),

                const SizedBox(height: 16),

                // ── Action Buttons ──
                _buildActionButtons(),

                const Spacer(),

                // ── Image Count Info ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_images.length} photo${_images.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: !_loading
          ? FloatingActionButton(
              onPressed: _showAddImageSheet,
              backgroundColor: VxrTokens.accent,
              child: const Icon(Icons.add_a_photo, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildImagePreview() {
    if (_images.isEmpty) {
      return Container(
        height: 300,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VxrTokens.surface2,
          borderRadius: BorderRadius.circular(VxrTokens.radius),
          border: Border.all(color: VxrTokens.border, width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VxrTokens.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: VxrTokens.accent, size: 22),
              ),
              const SizedBox(height: 12),
              const Text(
                'No photos yet',
                style: TextStyle(
                  fontSize: 14,
                  color: VxrTokens.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap + to add photos',
                style: TextStyle(fontSize: 12, color: VxrTokens.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showImageOptions(index),
                  child: _buildImageWidget(_images[index]),
                );
              },
            ),
          ),
          // Cover badge
          if (_images.isNotEmpty && _images[_currentPage].isCover)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: VxrTokens.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Cover',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Local badge
          if (_images.isNotEmpty && _images[_currentPage].isLocal)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Page indicator
          if (_images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_images.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? VxrTokens.accent
                          : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final isSelected = index == _currentPage;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 65,
              height: 65,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? VxrTokens.accent
                      : Colors.grey[300]!,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(_images[index]),
                    if (_images[index].isCover)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: VxrTokens.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star,
                              size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _setCover(_currentPage),
              icon: const Icon(Icons.star_outline, size: 18),
              label: const Text('Set as Cover'),
              style: OutlinedButton.styleFrom(
                foregroundColor: VxrTokens.accent,
                side: const BorderSide(color: VxrTokens.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _removeImage(_currentPage),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.fullscreen, color: VxrTokens.accent),
              title: const Text('View Full Screen'),
              onTap: () {
                Navigator.pop(ctx);
                _viewFullScreen(index);
              },
            ),
            if (!_images[index].isCover)
              ListTile(
                leading:
                    const Icon(Icons.star_outline, color: VxrTokens.accent),
                title: const Text('Set as Cover Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setCover(index);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _removeImage(index);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _viewFullScreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenPreview(
          images: _images,
          initialIndex: index,
        ),
      ),
    );
  }

  Widget _buildImageWidget(ListingImageItem item) {
    if (item.isLocal) {
      return Image.file(
        File(item.localFile!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    if (item.url != null && item.url!.isNotEmpty) {
      return Image.network(
        item.url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VxrTokens.accent,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _buildThumbnail(ListingImageItem item) {
    if (item.isLocal) {
      return Image.file(
        File(item.localFile!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderSmall(),
      );
    }
    if (item.url != null && item.url!.isNotEmpty) {
      return Image.network(
        item.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderSmall(),
      );
    }
    return _placeholderSmall();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text('No image', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _placeholderSmall() {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.image, size: 20, color: Colors.grey[500]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Full-screen preview with PageView + InteractiveViewer
// ══════════════════════════════════════════════════════════════
class _FullScreenPreview extends StatefulWidget {
  final List<ListingImageItem> images;
  final int initialIndex;

  const _FullScreenPreview({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenPreview> createState() => _FullScreenPreviewState();
}

class _FullScreenPreviewState extends State<_FullScreenPreview> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final item = widget.images[index];
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: item.isLocal
                      ? Image.file(
                          File(item.localFile!.path),
                          fit: BoxFit.contain,
                          width: double.infinity,
                        )
                      : Image.network(
                          item.url ?? '',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image,
                            size: 60,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          // Counter
          if (widget.images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
