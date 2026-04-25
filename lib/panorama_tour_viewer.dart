import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:google_fonts/google_fonts.dart';

const _kPrimary = Color(0xfff36c6c);


/// Data model for a room panorama in the tenant-side viewer.
class TourRoom {
  final String label;
  final String imageUrl;

  const TourRoom({required this.label, required this.imageUrl});
}

/// Tenant-side 360° tour viewer — shows all rooms as a swipeable PageView
/// with immersive PanoramaViewer for each room.
class PanoramaTourViewer extends StatefulWidget {
  /// List of rooms with labels and image URLs.
  final List<TourRoom> rooms;

  /// Optional listing title for the app bar.
  final String? listingTitle;

  const PanoramaTourViewer({
    super.key,
    required this.rooms,
    this.listingTitle,
  });

  @override
  State<PanoramaTourViewer> createState() => _PanoramaTourViewerState();
}

class _PanoramaTourViewerState extends State<PanoramaTourViewer> {
  late PageController _pageCtrl;
  int _currentRoom = 0;
  bool _gyroscopeEnabled = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Room panoramas in PageView
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.rooms.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _currentRoom = i);
              },
              itemBuilder: (context, index) {
                final room = widget.rooms[index];
                return PanoramaViewer(
                  sensorControl: _gyroscopeEnabled
                      ? SensorControl.orientation
                      : SensorControl.none,
                  minZoom: 0.5,
                  maxZoom: 5.0,
                  zoom: 1.0,
                  child: Image.network(
                    room.imageUrl,
                    fit: BoxFit.cover,
                    semanticLabel: '360° view of ${room.label}',
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image,
                                size: 48, color: Colors.white30),
                            const SizedBox(height: 12),
                            Text('Failed to load panorama',
                                style: GoogleFonts.inter(
                                    color: Colors.white54, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top controls bar (animated)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _showControls
                  ? MediaQuery.of(context).padding.top + 10
                  : -(MediaQuery.of(context).padding.top + 60),
              left: 10,
              right: 10,
              child: Row(
                children: [
                  // Back button
                  _circleBtn(Icons.close, () => Navigator.pop(context)),
                  const Spacer(),
                  // Room label & counter
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.rooms[_currentRoom].label}  •  ${_currentRoom + 1}/${widget.rooms.length}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Gyroscope toggle
                  _circleBtn(
                    _gyroscopeEnabled
                        ? Icons.screen_rotation
                        : Icons.screen_lock_rotation,
                    () {
                      HapticFeedback.lightImpact();
                      setState(() => _gyroscopeEnabled = !_gyroscopeEnabled);
                    },
                  ),
                ],
              ),
            ),

            // Bottom room selector
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _showControls
                  ? MediaQuery.of(context).padding.bottom + 12
                  : -80.0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Room thumbnails / chips
                  if (widget.rooms.length > 1)
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.rooms.length,
                        itemBuilder: (ctx, i) {
                          final isActive = i == _currentRoom;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                _pageCtrl.animateToPage(i,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? _kPrimary
                                      : Colors.black54,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isActive
                                        ? _kPrimary
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.view_in_ar,
                                      size: 14,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white60,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.rooms[i].label,
                                      style: GoogleFonts.inter(
                                        color: isActive
                                            ? Colors.white
                                            : Colors.white60,
                                        fontSize: 12,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Page indicators
                  if (widget.rooms.length > 1)
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
                                : Colors.white30,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                  if (widget.rooms.length <= 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swipe,
                              color: Colors.white60, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _gyroscopeEnabled
                                ? 'Move device to explore'
                                : 'Drag to explore • Pinch to zoom',
                            style: GoogleFonts.inter(
                                color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
}
