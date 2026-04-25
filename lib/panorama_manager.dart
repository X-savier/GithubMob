import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'property_data.dart';
import 'panorama_capture_screen.dart';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
const _kPrimary = Color(0xfff36c6c);
const _kCoral = Color(0xFFE8735A);
const _kBg = Color(0xFFF5F5F5);
const _kBorderColor = Color(0xFFDEDEDE);
const _kHintColor = Color(0xFFAAAAAA);
const _kLabelColor = Color(0xFF333333);
const _kTransitionDuration = Duration(milliseconds: 350);

// ─────────────────────────────────────────────
// ROOM PANORAMA ITEM MODEL
// ─────────────────────────────────────────────

/// Represents a single room's 360° panorama — either from DB or locally captured.
class RoomPanoramaItem {
  /// DB record ID (null for pending uploads)
  final String? id;

  /// Full URL for existing images (remote)
  final String? url;

  /// Local file for pending uploads
  final XFile? localFile;

  /// Room label — e.g. "Living Room", "Bedroom 1"
  String roomLabel;

  /// 'upload' or 'capture'
  final String uploadSource;

  /// Display order in the tour
  int sortOrder;

  RoomPanoramaItem({
    this.id,
    this.url,
    this.localFile,
    this.roomLabel = '',
    this.uploadSource = 'capture',
    this.sortOrder = 0,
  });

  bool get isLocal => localFile != null;
  bool get isRemote => url != null && !isLocal;
}

// ─────────────────────────────────────────────
// PANORAMA MANAGER SCREEN (LANDLORD SIDE)
// ─────────────────────────────────────────────

/// Main screen for managing 360° room panoramas for a listing.
/// Flow: Add Room → Capture 360° → Preview → Label → Publish with listing.
class PanoramaManagerScreen extends StatefulWidget {
  /// If editing an existing listing, pass the ID to load saved panoramas.
  final String? listingId;

  /// For new listings, pre-populate with locally captured panorama items.
  final List<RoomPanoramaItem>? initialRooms;

  const PanoramaManagerScreen({
    super.key,
    this.listingId,
    this.initialRooms,
  });

  @override
  State<PanoramaManagerScreen> createState() => _PanoramaManagerScreenState();
}

class _PanoramaManagerScreenState extends State<PanoramaManagerScreen> {
  final List<RoomPanoramaItem> _rooms = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  /// Load existing panorama records from DB and initial local rooms.
  Future<void> _loadRooms() async {
    setState(() => _loading = true);

    try {
      // Load existing panoramas from DB
      if (widget.listingId != null) {
        final records = await fetchListingImageRecords(widget.listingId!);
        for (final rec in records) {
          if ((rec['image_type'] ?? 'normal') != 'panorama') continue;
          _rooms.add(RoomPanoramaItem(
            id: rec['id'],
            url: buildStorageUrl(rec['image_url'] ?? ''),
            roomLabel: rec['room_label'] ?? 'Room ${_rooms.length + 1}',
            uploadSource: rec['upload_source'] ?? 'capture',
            sortOrder: rec['sort_order'] ?? _rooms.length,
          ));
        }
      }

      // Add initial local rooms
      if (widget.initialRooms != null) {
        _rooms.addAll(widget.initialRooms!);
      }
    } catch (e) {
      debugPrint('Error loading panoramas: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── ADD ROOM FLOW ──

  /// Start the add-room flow: choose capture or gallery upload.
  Future<void> _addRoom() async {
    HapticFeedback.mediumImpact();
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
            Text('Add Room Panorama',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Create a 360° view of a room',
                style: GoogleFonts.inter(fontSize: 12, color: _kHintColor)),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.view_in_ar, color: _kPrimary),
              ),
              title: Text('Capture 360° Panorama',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'Guided capture — rotate your phone to stitch a full room view',
                  style: GoogleFonts.inter(fontSize: 12, color: _kHintColor)),
              onTap: () => Navigator.pop(ctx, 'capture'),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: Text('Upload from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'Select an existing 360° equirectangular image',
                  style: GoogleFonts.inter(fontSize: 12, color: _kHintColor)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (action == 'capture') {
      await _capture360Panorama();
    } else if (action == 'gallery') {
      await _uploadFromGallery();
    }
  }

  /// Open Camera360 guided capture screen.
  Future<void> _capture360Panorama() async {
    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => const PanoramaCaptureScreen(),
      ),
    );

    if (result != null && mounted) {
      await _previewAndLabel(result, 'capture');
    }
  }

  /// Pick an existing panorama image from gallery.
  Future<void> _uploadFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked != null && mounted) {
        await _previewAndLabel(picked, 'upload');
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show panorama preview and label entry dialog before adding to list.
  Future<void> _previewAndLabel(XFile file, String source) async {
    final labelCtrl = TextEditingController(
        text: 'Room ${_rooms.length + 1}');
    bool confirmed = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Preview & Label',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Review your panorama and give the room a name',
                style: GoogleFonts.inter(fontSize: 13, color: _kHintColor)),
            const SizedBox(height: 16),

            // Panorama preview — interactive 360° viewer
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PanoramaViewer(
                      sensorControl: SensorControl.none,
                      minZoom: 0.5,
                      maxZoom: 3.0,
                      zoom: 1.0,
                      child: Image.file(
                        File(file.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image,
                              size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                    // 360° badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kCoral.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.view_in_ar,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('360°',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Drag hint
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swipe,
                                  color: Colors.white70, size: 12),
                              const SizedBox(width: 4),
                              Text('Drag to explore',
                                  style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Room label text field
            TextField(
              controller: labelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Room Name',
                hintText: 'e.g. Living Room, Bedroom 1, Kitchen',
                labelStyle: GoogleFonts.inter(color: _kLabelColor),
                hintStyle: GoogleFonts.inter(color: _kHintColor, fontSize: 13),
                prefixIcon: const Icon(Icons.label_outline, color: _kCoral),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 15),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Discard', style: GoogleFonts.inter()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      confirmed = true;
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('Add Room', style: GoogleFonts.inter()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _rooms.add(RoomPanoramaItem(
          localFile: file,
          roomLabel: labelCtrl.text.trim().isEmpty
              ? 'Room ${_rooms.length + 1}'
              : labelCtrl.text.trim(),
          uploadSource: source,
          sortOrder: _rooms.length,
        ));
      });
    }
    labelCtrl.dispose();
  }

  // ── EDIT ROOM LABEL ──

  /// Edit the label of an existing room.
  Future<void> _editRoomLabel(int index) async {
    final room = _rooms[index];
    final ctrl = TextEditingController(text: room.roomLabel);

    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Rename Room',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter room name',
            hintStyle: GoogleFonts.inter(color: _kHintColor),
            prefixIcon: const Icon(Icons.label_outline, color: _kCoral),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (newLabel != null && newLabel.isNotEmpty && mounted) {
      setState(() => _rooms[index].roomLabel = newLabel);
    }
  }

  // ── REMOVE ROOM ──

  /// Remove a room with confirmation.
  Future<void> _removeRoom(int index) async {
    final room = _rooms[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Remove Room',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Remove "${room.roomLabel}" from the tour? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: _kLabelColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Remove', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    HapticFeedback.mediumImpact();

    // Delete from DB if remote
    if (room.isRemote && room.id != null) {
      try {
        await deleteListingImage(room.id!);
      } catch (e) {
        debugPrint('Error deleting panorama: $e');
      }
    }

    setState(() {
      _rooms.removeAt(index);
      for (int i = 0; i < _rooms.length; i++) {
        _rooms[i].sortOrder = i;
      }
    });
  }

  // ── VIEW ROOM PANORAMA ──

  /// Open immersive 360° viewer for a single room.
  void _viewRoom(int index) {
    final room = _rooms[index];
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => _PanoramaFullScreenViewer(
          item: room,
          index: index,
          total: _rooms.length,
        ),
        transitionDuration: _kTransitionDuration,
        reverseTransitionDuration: _kTransitionDuration,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ── PREVIEW TOUR ──

  /// Preview the full 360° tour (all rooms in PageView).
  void _previewTour() {
    if (_rooms.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TourPreviewScreen(rooms: _rooms),
      ),
    );
  }

  // ── SAVE & RETURN ──

  /// Save rooms and return to manage_listing.
  Future<void> _saveAndReturn() async {
    // For new listings (no listingId), return rooms back
    if (widget.listingId == null) {
      Navigator.pop(context, _rooms);
      return;
    }

    // For existing listings, upload pending panoramas
    final pendingRooms = _rooms.where((r) => r.isLocal).toList();
    if (pendingRooms.isEmpty) {
      Navigator.pop(context, _rooms);
      return;
    }

    setState(() => _uploading = true);

    try {
      for (int i = 0; i < pendingRooms.length; i++) {
        final room = pendingRooms[i];
        final bytes = await room.localFile!.readAsBytes();
        final ext = room.localFile!.name.split('.').last;
        final path =
            '${widget.listingId}/pano_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        await Supabase.instance.client.storage
            .from('listing-images')
            .uploadBinary(path, bytes);

        // Save record with room_label
        await savePanoramaImage(
          listingId: widget.listingId!,
          storagePath: path,
          roomLabel: room.roomLabel,
          uploadSource: room.uploadSource,
          sortOrder: _rooms.indexOf(room),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Panoramas saved successfully',
                style: GoogleFonts.inter()),
            backgroundColor: _kPrimary,
          ),
        );
        Navigator.pop(context, _rooms);
      }
    } catch (e) {
      debugPrint('Panorama upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: _loading ? _buildLoading() : _buildBody(),
      floatingActionButton: !_loading
          ? FloatingActionButton.extended(
              onPressed: _addRoom,
              backgroundColor: _kPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Add Room',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        tooltip: 'Go back',
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '360° Room Tour',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        // Preview tour button
        if (_rooms.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.play_circle_outline, color: Colors.white),
            tooltip: 'Preview Tour',
            onPressed: _previewTour,
          ),
        // Save/Done button
        if (_rooms.any((r) => r.isLocal))
          TextButton(
            onPressed: _uploading ? null : _saveAndReturn,
            child: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Done',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
          ),
      ],
    );
  }

  /// Skeleton loading.
  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_rooms.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        // Room count header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                '${_rooms.length} Room${_rooms.length == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kLabelColor,
                ),
              ),
              const Spacer(),
              if (_rooms.length > 1)
                TextButton.icon(
                  onPressed: _previewTour,
                  icon: const Icon(Icons.play_circle_outline,
                      size: 18, color: _kCoral),
                  label: Text('Preview Tour',
                      style: GoogleFonts.inter(
                          color: _kCoral,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),

        // Room list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: _rooms.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              return _buildRoomCard(index);
            },
          ),
        ),
      ],
    );
  }

  /// Reorder rooms.
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _rooms.removeAt(oldIndex);
      _rooms.insert(newIndex, item);
      for (int i = 0; i < _rooms.length; i++) {
        _rooms[i].sortOrder = i;
      }
    });
    HapticFeedback.selectionClick();
  }

  /// Empty state CTA.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.view_in_ar, size: 64, color: _kCoral),
            ),
            const SizedBox(height: 24),
            Text(
              'Create a 360° Room Tour',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _kLabelColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add rooms to create an immersive virtual tour.\n'
              'Tenants will be able to explore each room in 360°.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _kHintColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildStepItem(1, 'Capture a 360° panorama of a room',
                Icons.camera_alt),
            const SizedBox(height: 12),
            _buildStepItem(
                2, 'Preview & label the room', Icons.label_outline),
            const SizedBox(height: 12),
            _buildStepItem(
                3, 'Repeat for each room, then publish', Icons.check_circle_outline),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addRoom,
              icon: const Icon(Icons.add, size: 20),
              label: Text('Add Your First Room',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int step, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$step',
                style: GoogleFonts.inter(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: _kCoral, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(fontSize: 13, color: _kLabelColor)),
        ),
      ],
    );
  }

  /// Build a room card with preview thumbnail, label, and actions.
  Widget _buildRoomCard(int index) {
    final room = _rooms[index];

    return Card(
      key: ValueKey('room_$index'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _viewRoom(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Drag handle
              const Icon(Icons.drag_handle, color: _kHintColor, size: 20),
              const SizedBox(width: 8),

              // Panorama thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThumbnail(room),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 4,
                        right: 4,
                        child: Icon(Icons.view_in_ar,
                            color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Room info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kLabelColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          room.isLocal ? Icons.cloud_upload_outlined : Icons.cloud_done,
                          size: 12,
                          color: room.isLocal ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          room.isLocal ? 'Pending upload' : 'Uploaded',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: room.isLocal ? Colors.orange : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Room ${index + 1}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _kHintColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: _kCoral,
                tooltip: 'Rename room',
                onPressed: () => _editRoomLabel(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red[400],
                tooltip: 'Remove room',
                onPressed: () => _removeRoom(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build thumbnail for a room panorama item.
  Widget _buildThumbnail(RoomPanoramaItem item) {
    if (item.isLocal) {
      return Image.file(
        File(item.localFile!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderThumb(),
      );
    }
    if (item.url != null && item.url!.isNotEmpty) {
      return Image.network(
        item.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderThumb(),
      );
    }
    return _placeholderThumb();
  }

  Widget _placeholderThumb() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.view_in_ar, size: 20, color: Colors.grey),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOUR PREVIEW SCREEN (LANDLORD PREVIEW)
// ═══════════════════════════════════════════════════════════════

/// Preview the full 360° tour as a tenant would see it.
class _TourPreviewScreen extends StatefulWidget {
  final List<RoomPanoramaItem> rooms;

  const _TourPreviewScreen({required this.rooms});

  @override
  State<_TourPreviewScreen> createState() => _TourPreviewScreenState();
}

class _TourPreviewScreenState extends State<_TourPreviewScreen> {
  late PageController _pageCtrl;
  int _currentRoom = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Room PageView
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.rooms.length,
            onPageChanged: (i) => setState(() => _currentRoom = i),
            itemBuilder: (context, index) {
              final room = widget.rooms[index];
              return PanoramaViewer(
                sensorControl: SensorControl.none,
                minZoom: 0.5,
                maxZoom: 5.0,
                zoom: 1.0,
                child: _buildPanoImage(room),
              );
            },
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                _circleBtn(Icons.close, () => Navigator.pop(context)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.rooms[_currentRoom].roomLabel}  •  ${_currentRoom + 1}/${widget.rooms.length}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
          ),

          // Bottom room indicator
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swipe, color: Colors.white60, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Swipe for next room • Drag to explore',
                        style: GoogleFonts.inter(
                            color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.rooms.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentRoom == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentRoom == i
                            ? _kPrimary
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Image _buildPanoImage(RoomPanoramaItem room) {
    if (room.isLocal) {
      return Image.file(File(room.localFile!.path), fit: BoxFit.cover);
    }
    return Image.network(room.url ?? '', fit: BoxFit.cover);
  }
}

// ═══════════════════════════════════════════════════════════════
// FULL-SCREEN PANORAMA VIEWER (SINGLE ROOM)
// ═══════════════════════════════════════════════════════════════

/// Full-screen 360° viewer for a single room panorama.
class _PanoramaFullScreenViewer extends StatefulWidget {
  final RoomPanoramaItem item;
  final int index;
  final int total;

  const _PanoramaFullScreenViewer({
    required this.item,
    required this.index,
    required this.total,
  });

  @override
  State<_PanoramaFullScreenViewer> createState() =>
      _PanoramaFullScreenViewerState();
}

class _PanoramaFullScreenViewerState extends State<_PanoramaFullScreenViewer> {
  bool _gyroscopeEnabled = false;
  bool _imageLoaded = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Panorama viewer
          if (!_hasError)
            PanoramaViewer(
              sensorControl: _gyroscopeEnabled
                  ? SensorControl.orientation
                  : SensorControl.none,
              minZoom: 0.5,
              maxZoom: 5.0,
              zoom: 1.0,
              onImageLoad: () {
                if (mounted) setState(() => _imageLoaded = true);
              },
              child: _buildPanoramaImage(),
            ),

          // Error state
          if (_hasError) _buildErrorState(),

          // Loading overlay
          if (!_imageLoaded && !_hasError)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                        color: _kPrimary, strokeWidth: 2.5),
                    const SizedBox(height: 16),
                    Text('Loading 360° view...',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),

          // Top bar controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _controlButton(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                  semanticLabel: 'Close panorama viewer',
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.item.roomLabel}  •  ${widget.index + 1}/${widget.total}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _controlButton(
                  icon: _gyroscopeEnabled
                      ? Icons.screen_rotation
                      : Icons.screen_lock_rotation,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _gyroscopeEnabled = !_gyroscopeEnabled);
                  },
                  semanticLabel: _gyroscopeEnabled
                      ? 'Disable gyroscope'
                      : 'Enable gyroscope',
                ),
              ],
            ),
          ),

          // Bottom hint
          if (_imageLoaded)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swipe, color: Colors.white60, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _gyroscopeEnabled
                            ? 'Move device to explore'
                            : 'Drag to explore • Pinch to zoom',
                        style: GoogleFonts.inter(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Image _buildPanoramaImage() {
    final item = widget.item;
    if (item.isLocal) {
      return Image.file(
        File(item.localFile!.path),
        fit: BoxFit.cover,
        semanticLabel: '360° view of ${item.roomLabel}',
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return const SizedBox.shrink();
        },
      );
    }
    return Image.network(
      item.url ?? '',
      fit: BoxFit.cover,
      semanticLabel: '360° view of ${item.roomLabel}',
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hasError = true);
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.broken_image,
                size: 60, color: Colors.white30),
          ),
          const SizedBox(height: 20),
          Text('Failed to load panorama',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('The image could not be displayed',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _imageLoaded = false;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Retry', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
