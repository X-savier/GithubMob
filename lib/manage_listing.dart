import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contract_templates.dart';
import 'property_data.dart';
import 'listing_image_manager.dart';
import 'panorama_manager.dart';
import 'psgc_location_field.dart';
import 'verification_screen.dart';

const String _mapsApiKey = 'AIzaSyAyclCsU4xb9g0i2jCEPkaM4D5bACDwXbo';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
const kCoral = VxrTokens.accent;
const kRedSelected = Color(0xFFC0392B);
const kPageBg = VxrTokens.bg;
const kBorderColor = VxrTokens.border;
const kHintColor = VxrTokens.textMuted;
const kLabelColor = VxrTokens.textSub;
const kSectionTitle = VxrTokens.text;
const _listingLoadTimeout = Duration(seconds: 15);

// ─────────────────────────────────────────────
// LISTING DATA MODEL
// ─────────────────────────────────────────────
class ListingData {
  String? id;
  String title;
  String location;
  String price;
  String beds;
  String baths;
  String sqm;
  String? imageUrl;
  XFile? coverPhoto;
  List<XFile> propertyImages;

  ListingData({
    this.id,
    required this.title,
    required this.location,
    required this.price,
    required this.beds,
    required this.baths,
    required this.sqm,
    this.imageUrl,
    this.coverPhoto,
    this.propertyImages = const [],
  });

  /// Create from a Property object (Supabase data)
  factory ListingData.fromProperty(Property p) {
    return ListingData(
      id: p.id,
      title: p.title,
      location: p.location,
      price: p.price.replaceAll(RegExp(r'[^\d.]'), ''),
      beds: p.beds == 0 ? 'Studio' : p.beds.toString(),
      baths: p.baths,
      sqm: p.area.replaceAll('m²', ''),
      imageUrl: p.image,
    );
  }
}

// ─────────────────────────────────────────────
// MANAGE LISTING SCREEN
// ─────────────────────────────────────────────
class ManageListingScreen extends StatefulWidget {
  const ManageListingScreen({super.key});

  @override
  State<ManageListingScreen> createState() => _ManageListingScreenState();
}

class _ManageListingScreenState extends State<ManageListingScreen> {
  List<ListingData> _listings = [];
  bool _isLoading = true;
  bool _hasRenderedShell = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('ManageListingScreen initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: avoid_print
      print('ManageListingScreen first frame rendered');
      if (!mounted) return;
      setState(() => _hasRenderedShell = true);
      // Kick the load on the very next frame so the shell paints first
      // but we do not introduce a fake delay that could hide a hang.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: avoid_print
        print('ManageListingScreen load kickoff');
        if (mounted) _loadListings();
      });
    });
  }

  Future<void> _loadListings() async {
    // ignore: avoid_print
    print('ManageListingScreen _loadListings ENTER');
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    final startedAt = DateTime.now();
    // ignore: avoid_print
    print('ManageListingScreen load listings started');
    try {
      // ignore: avoid_print
      print('ManageListingScreen awaiting fetchLandlordListings');
      final properties = await fetchLandlordListings(throwOnError: true).timeout(
        _listingLoadTimeout,
        onTimeout: () => throw TimeoutException(
          'Loading listings took longer than ${_listingLoadTimeout.inSeconds} seconds.',
        ),
      );
      // ignore: avoid_print
      print(
        'ManageListingScreen fetchLandlordListings returned ${properties.length}',
      );
      final listings = properties
          .map((property) => ListingData.fromProperty(property))
          .toList();
      // ignore: avoid_print
      print(
        'ManageListingScreen loaded ${listings.length} listings in '
        '${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _isLoading = false;
      });
    } on TimeoutException catch (e) {
      // ignore: avoid_print
      print('ManageListingScreen load listings timeout: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'Loading your listings is taking too long. Check your connection and try again.';
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('ManageListingScreen load listings ERROR: $e');
      // ignore: avoid_print
      print('ManageListingScreen load listings STACK: $st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'Could not load your listings right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print(
      'ManageListingScreen build start shell=$_hasRenderedShell loading=$_isLoading',
    );

    if (!_hasRenderedShell) {
      // ignore: avoid_print
      print('ManageListingScreen build end shell');
      return Scaffold(
        backgroundColor: kPageBg,
        body: SafeArea(child: _buildOpeningState()),
      );
    }

    final scaffold = Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Listing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _goToCreateListing,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    'Create New Listing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    // Override the global ElevatedButtonTheme which forces
                    // a full-width minimum size; that breaks layout when
                    // the button is placed inside a Row.
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildListingsBody()),
          ],
        ),
      ),
    );

    // ignore: avoid_print
    print('ManageListingScreen build end');
    return scaffold;
  }

  Widget _buildListingsBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_loadError != null) return _buildErrorState(_loadError!);
    if (_listings.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: _loadListings,
      color: kCoral,
      child: ListView.separated(
        itemCount: _listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) =>
            _buildListingCard(_listings[index], index),
      ),
    );
  }

  Widget _buildOpeningState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.list_alt_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'Opening listings...',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    ),
  );

  Widget _buildLoadingState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.home_work_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'Loading your listings...',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    ),
  );

  Widget _buildErrorState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Listings unavailable',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadListings,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'No listings yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap "Create New Listing" to add your first property',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildListingCard(ListingData listing, int index) => Container(
    decoration: BoxDecoration(
      color: VxrTokens.surface,
      borderRadius: BorderRadius.circular(VxrTokens.radius),
      border: Border.all(color: VxrTokens.border),
      boxShadow: VxrTokens.shadowSm,
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _buildCardImage(listing),
            Positioned(top: 10, right: 10, child: _buildCardActions(index)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kSectionTitle,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: kHintColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      listing.location,
                      style: const TextStyle(fontSize: 13, color: kHintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: kBorderColor),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '₱${listing.price}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kCoral,
                          ),
                        ),
                        const TextSpan(
                          text: '/month',
                          style: TextStyle(fontSize: 12, color: kHintColor),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      _statChip('${listing.beds} Bed', Icons.bed_outlined),
                      _statChip(
                        '${listing.baths} Bath',
                        Icons.bathtub_outlined,
                      ),
                      _statChip('${listing.sqm}m', Icons.straighten_outlined),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildCardActions(int index) => Row(
    children: [
      _buildActionButton(
        icon: Icons.edit_outlined,
        label: 'Edit',
        color: kCoral,
        onTap: () => _editListing(index),
      ),
      const SizedBox(width: 6),
      _buildActionButton(
        icon: Icons.delete_outline,
        label: 'Delete',
        color: kRedSelected,
        onTap: () => _confirmDelete(index),
      ),
    ],
  );

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  void _confirmDelete(int index) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Delete Listing',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: const Text(
        'Are you sure you want to delete this listing? This action cannot be undone.',
        style: TextStyle(fontSize: 13, color: kHintColor),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: kLabelColor)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final listing = _listings[index];
            if (listing.id != null) {
              final ok = await deleteListingFromSupabase(listing.id!);
              if (ok && mounted) {
                setState(() => _listings.removeAt(index));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Listing deleted')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete listing')),
                );
              }
            } else {
              setState(() => _listings.removeAt(index));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kRedSelected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  Future<void> _editListing(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateListingScreen(existingListingId: _listings[index].id),
      ),
    );
    if (result == true) _loadListings();
  }

  Widget _buildCardImage(ListingData listing) {
    // Show local image if available
    final XFile? imageFile =
        listing.coverPhoto ??
        (listing.propertyImages.isNotEmpty
            ? listing.propertyImages.first
            : null);
    if (imageFile != null) {
      return SizedBox(
        height: 180,
        width: double.infinity,
        child: XFileImage(
          file: imageFile,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 180,
        ),
      );
    }
    // Show Supabase image URL if available
    if (listing.imageUrl != null && listing.imageUrl!.isNotEmpty) {
      return SizedBox(
        height: 180,
        width: double.infinity,
        child: Image.network(
          listing.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 180,
          errorBuilder: (_, _, _) => _cardImagePlaceholder(),
        ),
      );
    }
    return _cardImagePlaceholder();
  }

  Widget _cardImagePlaceholder() => Container(
    height: 180,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFCFD8DC), Color(0xFFB0BEC5)],
      ),
    ),
    child: const Center(
      child: Icon(Icons.home_work_outlined, size: 48, color: Colors.white54),
    ),
  );

  Widget _statChip(String label, IconData icon) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: kHintColor),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: kHintColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Future<void> _goToCreateListing() async {
    final canCreate = await ensureVerifiedToCreateListing(context);
    if (!canCreate || !mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (result == true) _loadListings();
  }
}

// ─────────────────────────────────────────────
// CREATE LISTING SCREEN
// ─────────────────────────────────────────────
class CreateListingScreen extends StatefulWidget {
  final String? existingListingId;
  const CreateListingScreen({super.key, this.existingListingId});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _listingTitleCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _fullAddressCtrl = TextEditingController();
  final _streetAreaCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _maxOccupantsCtrl = TextEditingController();
  final _squareMeterCtrl = TextEditingController();
  final _aboutPlaceCtrl = TextEditingController();
  final _unitDetailsCtrl = TextEditingController();
  final _hostNameCtrl = TextEditingController();
  final _monthlyRentCtrl = TextEditingController(text: '0.00');
  final _securityDepositCtrl = TextEditingController(text: '0.00');
  final _advancePaymentCtrl = TextEditingController(text: '0.00');

  bool _isActive = true;
  String? _propertyType,
      _furnishing,
      _bedrooms,
      _bathrooms,
      _paymentTerms,
      _paymentMethod,
      _hostRole;
  bool _isImmediate = true;
  DateTime? _availableFrom;
  String _leaseTerm = '12 months';
  // 'lease' (fixed term) or 'rent' (month-to-month). Drives which
  // contract template the tenant + landlord see post-approval.
  String _listingType = 'lease';

  final Map<String, bool> _amenities = {
    'Air Conditioning': false,
    'Bed': false,
    'Cabinet': false,
    'Refrigerator': false,
    'Stove': false,
    'Washing Machine': false,
    'Water Heater': false,
    'Balcony': false,
    'Storage': false,
  };

  // Utilities
  bool _withWater = false,
      _withElectricity = false,
      _withInternet = false,
      _withParking = false;

  // Building features
  bool _hasSecurity = false,
      _hasElevator = false,
      _hasBackupPower = false,
      _hasPool = false,
      _hasGym = false,
      _hasLaundryArea = false,
      _hasFunctionHall = false,
      _hasPlayground = false;

  bool _petsAllowed = false,
      _smokingAllowed = false,
      _noCurfew = true,
      _sublettingAllowed = false,
      _modificationAllowed = false;
  String _guestPolicy = 'Day/Nite Only', _responseTime = 'Within 1 Hour';

  // ── Contract template state ──
  // Either a freshly-picked file (not yet uploaded) or a previously
  // saved file referenced by storage path + display name. The two
  // states are mutually exclusive: selecting a new file clears the
  // remote reference and vice versa.
  PlatformFile? _contractTemplateFile;
  String? _contractTemplateUrl; // storage path saved on the listing
  String? _contractTemplateName; // original filename for display

  // Landlord-edited terms. `null` means "use the per-type defaults"
  // from contract_templates.dart at contract-signing time.
  List<String>? _termsOverride;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _propertyImages = [];
  List<RoomPanoramaItem> _media360Rooms = [];
  XFile? _coverPhoto;

  // ── Listing verification ──
  // Proof-of-ownership document (required for new listings).
  // [_verificationDoc] is a freshly-picked file; [_verificationDocUrl]
  // is the saved storage path on existing listings.
  XFile? _verificationDoc;
  String? _verificationDocUrl;
  bool _listingVerified = false;

  // Map state
  GoogleMapController? _mapController;
  LatLng _mapPosition = const LatLng(14.3270, 120.9540);
  double _mapZoom = 14;
  Set<Marker> _mapMarkers = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingListingId != null) {
      _loadExistingListing();
    }
  }

  Future<void> _loadExistingListing() async {
    final data = await fetchListingDetails(widget.existingListingId!);
    if (data != null && mounted) {
      setState(() {
        _listingTitleCtrl.text = data['title']?.toString() ?? '';
        _isActive = (data['status'] ?? 'active') == 'active';
        _aboutPlaceCtrl.text = data['description']?.toString() ?? '';
        _propertyType = data['property_type']?.toString();
        _cityCtrl.text = data['city']?.toString() ?? '';
        _provinceCtrl.text = data['province']?.toString() ?? '';
        _fullAddressCtrl.text = data['full_address']?.toString() ?? '';
        _postalCodeCtrl.text = data['postal_code']?.toString() ?? '';
        _streetAreaCtrl.text = data['barangay']?.toString() ?? '';
        _verificationDocUrl = data['verification_doc_url']?.toString();
        _listingVerified = data['is_verified'] == true;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          _mapPosition = LatLng(lat, lng);
          _mapZoom = 16;
          _mapMarkers = {
            Marker(
              markerId: const MarkerId('selected'),
              position: _mapPosition,
              infoWindow: InfoWindow(
                title: data['full_address']?.toString() ?? 'Selected Location',
              ),
            ),
          };
        }
        _bedrooms = data['bedrooms']?.toString();
        _bathrooms = data['bathrooms']?.toString();
        _maxOccupantsCtrl.text = data['max_occupants']?.toString() ?? '';
        _squareMeterCtrl.text = data['square_meters']?.toString() ?? '';
        _furnishing = data['furnishing']?.toString();
        _monthlyRentCtrl.text = data['monthly_rent']?.toString() ?? '0.00';
        _securityDepositCtrl.text =
            data['security_deposit']?.toString() ?? '0.00';
        _advancePaymentCtrl.text =
            data['advance_payment']?.toString() ?? '0.00';
        _paymentTerms = data['payment_terms']?.toString();
        _paymentMethod = data['payment_method']?.toString();
        _isImmediate = data['is_immediate'] == true;
        if (data['available_from'] != null) {
          _availableFrom = DateTime.tryParse(data['available_from'].toString());
        }
        _leaseTerm = data['lease_term']?.toString() ?? '12 months';
        _listingType = data['listing_type']?.toString() ?? 'lease';
        _petsAllowed = data['pets_allowed'] == true;
        _smokingAllowed = data['smoking_allowed'] == true;
        _noCurfew = data['no_curfew'] == true;
        _sublettingAllowed = data['subletting_allowed'] == true;
        _modificationAllowed = data['modification_allowed'] == true;
        _guestPolicy = data['guest_policy']?.toString() ?? 'Day/Nite Only';
        _hostNameCtrl.text = data['host_name']?.toString() ?? '';
        _hostRole = data['host_role']?.toString();
        _responseTime = data['response_time']?.toString() ?? 'Within 1 Hour';
        // Amenities
        _amenities['Air Conditioning'] = data['has_aircon'] == true;
        _amenities['Bed'] = data['has_bed'] == true;
        _amenities['Cabinet'] = data['has_cabinet'] == true;
        _amenities['Refrigerator'] = data['has_refrigerator'] == true;
        _amenities['Stove'] = data['has_stove'] == true;
        _amenities['Washing Machine'] = data['has_washing_machine'] == true;
        _amenities['Water Heater'] = data['has_water_heater'] == true;
        _amenities['Balcony'] = data['has_balcony'] == true;
        _amenities['Storage'] = data['has_storage'] == true;
        // Utilities
        _withWater = data['with_water'] == true;
        _withElectricity = data['with_electricity'] == true;
        _withInternet = data['with_internet'] == true;
        _withParking = data['with_parking'] == true;
        // Building features
        _hasSecurity = data['has_security'] == true;
        _hasElevator = data['has_elevator'] == true;
        _hasBackupPower = data['has_backup_power'] == true;
        _hasPool = data['has_pool'] == true;
        _hasGym = data['has_gym'] == true;
        _hasLaundryArea = data['has_laundry_area'] == true;
        _hasFunctionHall = data['has_function_hall'] == true;
        _hasPlayground = data['has_playground'] == true;
        // Contract template + landlord-customized terms.
        // Columns are nullable and may be missing on older listings —
        // treat all of these as best-effort.
        _contractTemplateUrl = data['contract_template_url']?.toString();
        _contractTemplateName = data['contract_template_name']?.toString();
        final rawTerms = data['terms_override'];
        if (rawTerms is List) {
          _termsOverride = rawTerms
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (rawTerms is String && rawTerms.isNotEmpty) {
          // Some Postgres clients return JSONB as a JSON-encoded string.
          try {
            final decoded = jsonDecode(rawTerms);
            if (decoded is List) {
              _termsOverride = decoded
                  .map((e) => e?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          } catch (_) {
            /* leave as null */
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (var ctrl in [
      _listingTitleCtrl,
      _cityCtrl,
      _provinceCtrl,
      _fullAddressCtrl,
      _streetAreaCtrl,
      _postalCodeCtrl,
      _maxOccupantsCtrl,
      _squareMeterCtrl,
      _aboutPlaceCtrl,
      _unitDetailsCtrl,
      _hostNameCtrl,
      _monthlyRentCtrl,
      _securityDepositCtrl,
      _advancePaymentCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                'V',
                style: TextStyle(
                  color: kCoral,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ViewxRent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.existingListingId != null
                    ? 'Edit Listing'
                    : 'Create New Listing',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: kCoral,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildListingTypeSelector(),
            _buildListingTitleSection(),
            _buildLocationDetailsSection(),
            _buildPropertyDetailsSection(),
            _buildRentalPricingSection(),
            _buildAvailabilityLeaseSection(),
            _buildUnitDescriptionSection(),
            _buildAmenitiesSection(),
            _buildUtilitiesSection(),
            _buildBuildingFeaturesSection(),
            _buildRulesAndPoliciesSection(),
            _buildTermsAndConditionsSection(),
            _buildContractTemplateSection(),
            _buildHostInformationSection(),
            _buildMediaUploadSection(),
            _buildPropertyVerificationSection(),
            const SizedBox(height: 24),
            _buildBottomButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: VxrTokens.surface,
          borderRadius: BorderRadius.circular(VxrTokens.radius),
          border: Border.all(color: VxrTokens.border),
          boxShadow: VxrTokens.shadowSm,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kSectionTitle,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: kLabelColor,
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kHintColor, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: kBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: kBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: kCoral, width: 1.5),
    ),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    hint: Text(hint, style: const TextStyle(color: kHintColor, fontSize: 13)),
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kCoral, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
    icon: const Icon(
      Icons.keyboard_arrow_down,
      color: Colors.black54,
      size: 20,
    ),
    style: const TextStyle(color: kLabelColor, fontSize: 13),
    items: items
        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
        .toList(),
    onChanged: onChanged,
  );

  Widget _redRadio<T>({
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
    required String label,
  }) => GestureDetector(
    onTap: () => onChanged(value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: value == groupValue ? kRedSelected : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: value == groupValue
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kRedSelected,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: kLabelColor)),
      ],
    ),
  );

  Widget _squareCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) => GestureDetector(
    onTap: () => onChanged(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(
              color: value ? kCoral : Colors.grey.shade400,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(2),
            color: value ? kCoral : Colors.white,
          ),
          child: value
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: kLabelColor)),
      ],
    ),
  );

  // IMPROVED: Listing Title Section - Now properly left-aligned
  // ─────────────────────────────────────────────
  // LISTING TYPE SELECTOR (top of form)
  // ─────────────────────────────────────────────
  // Drives downstream UI: which Rules & Policies labels to show,
  // which Terms & Conditions to surface, and which contract
  // template (lease vs month-to-month rent) to ship to the
  // tenant after approval.
  Widget _buildListingTypeSelector() => _sectionCard(
    title: 'Listing Type',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose how this property is offered. This drives the rental '
          'rules, terms & conditions, and contract template tenants will '
          'see and sign.',
          style: TextStyle(fontSize: 12, color: kHintColor, height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _listingTypeCard(
                value: 'rent',
                title: 'For Rent',
                subtitle:
                    'Month-to-month, auto-renews each month with '
                    '30-day notice to terminate.',
                icon: Icons.event_repeat_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _listingTypeCard(
                value: 'lease',
                title: 'For Lease',
                subtitle:
                    'Fixed term (e.g. 12 months). Early termination '
                    'forfeits the security deposit.',
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _listingTypeCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _listingType == value;
    return GestureDetector(
      onTap: () {
        if (_listingType == value) return;
        setState(() {
          _listingType = value;
          // Wipe any landlord overrides — they were authored against
          // the previous type's defaults and would not make sense
          // mixed with the new template.
          _termsOverride = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kCoral.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kCoral : kBorderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? kCoral.withValues(alpha: 0.15)
                        : const Color(0xFFF1F1F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? kCoral : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? kCoral : kSectionTitle,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? kCoral : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: kLabelColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingTitleSection() => _sectionCard(
    title: 'Listing Title',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Listing Status'),
            Wrap(
              spacing: 16,
              children: [
                _redRadio<bool>(
                  value: true,
                  groupValue: _isActive,
                  onChanged: (_) => setState(() => _isActive = true),
                  label: 'Active',
                ),
                _redRadio<bool>(
                  value: false,
                  groupValue: _isActive,
                  onChanged: (_) => setState(() => _isActive = false),
                  label: 'Inactive',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Listing Title'),
            TextField(
              controller: _listingTitleCtrl,
              decoration: _inputDecoration('Enter listing title'),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Pick address from map ──
  Future<void> _pickAddressFromMap() async {
    LatLng? initialPos;

    // Try to get current device location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          initialPos = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}

    // If user already has an address in the form, use the map's current position
    if (_mapMarkers.isNotEmpty) {
      initialPos = _mapMarkers.first.position;
    }

    // Fallback to default
    initialPos ??= const LatLng(14.3270, 120.9540);

    if (!mounted) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _ListingMapAddressPicker(initialPosition: initialPos!),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result['full_address']?.isNotEmpty == true) {
          _fullAddressCtrl.text = result['full_address']!;
        }
        if (result['city']?.isNotEmpty == true) {
          _cityCtrl.text = result['city']!;
        }
        if (result['province']?.isNotEmpty == true) {
          _provinceCtrl.text = result['province']!;
        }
        if (result['barangay']?.isNotEmpty == true) {
          _streetAreaCtrl.text = result['barangay']!;
        }
        if (result['postal_code']?.isNotEmpty == true) {
          _postalCodeCtrl.text = result['postal_code']!;
        }

        // Update map preview
        final lat = double.tryParse(result['lat'] ?? '');
        final lng = double.tryParse(result['lng'] ?? '');
        if (lat != null && lng != null) {
          _mapPosition = LatLng(lat, lng);
          _mapZoom = 16;
          _mapMarkers = {
            Marker(
              markerId: const MarkerId('selected'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: result['full_address'] ?? 'Selected Location',
              ),
            ),
          };
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
          );
        }
      });
    }
  }

  Widget _buildLocationDetailsSection() => _sectionCard(
    title: 'Location Details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PsgcLocationField(
          initialProvinceName: _provinceCtrl.text,
          initialCityName: _cityCtrl.text,
          initialBarangayName: _streetAreaCtrl.text,
          onChanged: (val) {
            // Persist the human-readable names to the existing controllers
            // so the save path (which writes city/province/barangay strings)
            // continues to work unchanged. NCR has no provinces, so we fall
            // back to the region name in the province slot.
            _provinceCtrl.text = val.province?.name ?? val.region?.name ?? '';
            _cityCtrl.text = val.city?.name ?? '';
            _streetAreaCtrl.text = val.barangay?.name ?? '';
          },
        ),
        const SizedBox(height: 12),
        _fieldLabel('Full Address'),
        TextField(
          controller: _fullAddressCtrl,
          decoration: _inputDecoration('Enter full Address'),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        _fieldLabel('Postal Code'),
        TextField(
          controller: _postalCodeCtrl,
          decoration: _inputDecoration('Enter postal code'),
          style: const TextStyle(fontSize: 13),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        _fieldLabel('Map:'),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _mapPosition,
                zoom: _mapZoom,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _mapMarkers,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              zoomGesturesEnabled: false,
              liteModeEnabled: true,
              onTap: (_) => _pickAddressFromMap(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickAddressFromMap,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Pick Address from Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCoral,
              side: const BorderSide(color: kCoral),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildPropertyDetailsSection() => _sectionCard(
    title: 'Property Details',
    child: Column(
      children: [
        _buildThreeColumnRow(
          child1: _buildDropdownColumn('Property Type:', _propertyType, [
            'House',
            'Apartment',
            'Condo',
            'Studio',
            'Room',
            'Townhouse',
          ], (v) => setState(() => _propertyType = v)),
          child2: _buildDropdownColumn('Furnishing:', _furnishing, [
            'Fully Furnished',
            'Semi-Furnished',
            'Unfurnished',
          ], (v) => setState(() => _furnishing = v)),
          child3: _buildDropdownColumn('Bedrooms:', _bedrooms, [
            'Studio',
            '1',
            '2',
            '3',
            '4',
            '5+',
          ], (v) => setState(() => _bedrooms = v)),
        ),
        const SizedBox(height: 12),
        _buildThreeColumnRow(
          child1: _buildDropdownColumn('Bathrooms:', _bathrooms, [
            '1',
            '2',
            '3',
            '4+',
          ], (v) => setState(() => _bathrooms = v)),
          child2: _buildTextFieldColumn(
            'Maximum Occupants:',
            _maxOccupantsCtrl,
            '',
            isNumber: true,
          ),
          child3: _buildSquareMeterField(),
        ),
      ],
    ),
  );

  Widget _buildRentalPricingSection() => _sectionCard(
    title: 'Rental Pricing',
    child: Column(
      children: [
        _buildThreeColumnRow(
          child1: _buildPriceField('Monthly Rent:', _monthlyRentCtrl),
          child2: _buildPriceField('Security Deposit:', _securityDepositCtrl),
          child3: _buildPriceField('Advance Payment:', _advancePaymentCtrl),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnRow(
          child1: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Payment Terms:'),
              _dropdown(
                hint: 'Select payment terms',
                value: _paymentTerms,
                items: ['Monthly', 'Quarterly', 'Semi-Annual', 'Annual'],
                onChanged: (v) => setState(() => _paymentTerms = v),
              ),
            ],
          ),
          child2: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Payment Method:'),
              _dropdown(
                hint: 'Select payment method',
                value: _paymentMethod,
                items: [
                  'Post-Dated Checks',
                  'Bank Transfer',
                  'GCash',
                  'Maya',
                  'Cash',
                  'Any',
                ],
                onChanged: (v) => setState(() => _paymentMethod = v),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildAvailabilityLeaseSection() => _sectionCard(
    title: 'Availability & Lease',
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 200
              : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Availability Status:'),
              Wrap(
                spacing: 12,
                children: [
                  _redRadio<bool>(
                    value: true,
                    groupValue: _isImmediate,
                    onChanged: (_) => setState(() => _isImmediate = true),
                    label: 'Immediate',
                  ),
                  _redRadio<bool>(
                    value: false,
                    groupValue: _isImmediate,
                    onChanged: (_) => setState(() => _isImmediate = false),
                    label: 'Future Date',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 200
              : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Available From:'),
              TextField(
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (date != null) setState(() => _availableFrom = date);
                },
                controller: TextEditingController(
                  text: _availableFrom != null
                      ? '${_availableFrom!.day.toString().padLeft(2, '0')}/${_availableFrom!.month.toString().padLeft(2, '0')}/${_availableFrom!.year}'
                      : '',
                ),
                decoration: _inputDecoration('dd/mm/yyyy').copyWith(
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: kHintColor,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        // Lease term only matters for fixed-term lease listings.
        // For month-to-month rent we hide it to reduce clutter; the
        // contract template hard-codes the auto-renew language.
        if (_listingType == 'lease')
          SizedBox(
            width: MediaQuery.of(context).size.width > 600
                ? 220
                : double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Lease Term (Months):'),
                _dropdown(
                  hint: '12 months',
                  value: _leaseTerm,
                  items: [
                    '1 month',
                    '3 months',
                    '6 months',
                    '12 months',
                    '24 months',
                  ],
                  onChanged: (v) =>
                      setState(() => _leaseTerm = v ?? '12 months'),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildUnitDescriptionSection() => _sectionCard(
    title: 'Unit Description',
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width / 2 - 40
              : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('About The Place:'),
              TextField(
                controller: _aboutPlaceCtrl,
                maxLines: 5,
                decoration: _inputDecoration(
                  'Describe the apartment, its features, etc.',
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width / 2 - 40
              : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Unit Details:'),
              TextField(
                controller: _unitDetailsCtrl,
                maxLines: 5,
                decoration: _inputDecoration('Additional room/area: The unit'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // IMPROVED: Amenities Section - 2-column grid, left-aligned
  Widget _buildAmenitiesSection() => _sectionCard(
    title: 'Amenities & Features',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select all amenities that are available',
          style: TextStyle(fontSize: 12, color: kHintColor),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3.5,
          children: _amenities.keys.map((key) {
            return Row(
              children: [
                _squareCheckbox(
                  value: _amenities[key]!,
                  onChanged: (v) =>
                      setState(() => _amenities[key] = v ?? false),
                  label: '',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key,
                    style: const TextStyle(fontSize: 13, color: kLabelColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _buildUtilitiesSection() => _sectionCard(
    title: 'Utilities & Inclusions',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select included utilities',
          style: TextStyle(fontSize: 12, color: kHintColor),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _squareCheckbox(
              value: _withWater,
              onChanged: (v) => setState(() => _withWater = v ?? false),
              label: 'Water',
            ),
            _squareCheckbox(
              value: _withElectricity,
              onChanged: (v) => setState(() => _withElectricity = v ?? false),
              label: 'Electricity',
            ),
            _squareCheckbox(
              value: _withInternet,
              onChanged: (v) => setState(() => _withInternet = v ?? false),
              label: 'Internet',
            ),
            _squareCheckbox(
              value: _withParking,
              onChanged: (v) => setState(() => _withParking = v ?? false),
              label: 'Parking',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBuildingFeaturesSection() => _sectionCard(
    title: 'Building Features',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select available building features',
          style: TextStyle(fontSize: 12, color: kHintColor),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3.5,
          children: [
            _buildFeatureCheckbox(
              'Security',
              _hasSecurity,
              (v) => setState(() => _hasSecurity = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Elevator',
              _hasElevator,
              (v) => setState(() => _hasElevator = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Backup Power',
              _hasBackupPower,
              (v) => setState(() => _hasBackupPower = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Pool',
              _hasPool,
              (v) => setState(() => _hasPool = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Gym',
              _hasGym,
              (v) => setState(() => _hasGym = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Laundry Area',
              _hasLaundryArea,
              (v) => setState(() => _hasLaundryArea = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Function Hall',
              _hasFunctionHall,
              (v) => setState(() => _hasFunctionHall = v ?? false),
            ),
            _buildFeatureCheckbox(
              'Playground',
              _hasPlayground,
              (v) => setState(() => _hasPlayground = v ?? false),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildFeatureCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) => Row(
    children: [
      _squareCheckbox(value: value, onChanged: onChanged, label: ''),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: kLabelColor),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _buildRulesAndPoliciesSection() {
    final isLease = _listingType == 'lease';
    return _sectionCard(
      title: isLease ? 'Lease Rules & Policies' : 'Rental Rules & Policies',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: kCoral.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kCoral.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  isLease ? Icons.assignment_outlined : Icons.event_repeat,
                  size: 16,
                  color: kCoral,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLease
                        ? 'These policies apply to a fixed-term lease and '
                              'will be referenced in the lease agreement.'
                        : 'These policies apply to a month-to-month rental '
                              'and will be referenced in the rental agreement.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: kLabelColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? 200
                    : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Pets allowed:'),
                    Wrap(
                      spacing: 16,
                      children: [
                        _redRadio<bool>(
                          value: true,
                          groupValue: _petsAllowed,
                          onChanged: (_) => setState(() => _petsAllowed = true),
                          label: 'Yes',
                        ),
                        _redRadio<bool>(
                          value: false,
                          groupValue: _petsAllowed,
                          onChanged: (_) =>
                              setState(() => _petsAllowed = false),
                          label: 'No',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? 200
                    : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Smoking Allowed:'),
                    Wrap(
                      spacing: 16,
                      children: [
                        _redRadio<bool>(
                          value: true,
                          groupValue: _smokingAllowed,
                          onChanged: (_) =>
                              setState(() => _smokingAllowed = true),
                          label: 'Yes',
                        ),
                        _redRadio<bool>(
                          value: false,
                          groupValue: _smokingAllowed,
                          onChanged: (_) =>
                              setState(() => _smokingAllowed = false),
                          label: 'No',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? 200
                    : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Guest Policy:'),
                    _dropdown(
                      hint: 'Day/Nite Only',
                      value: _guestPolicy,
                      items: [
                        'Day/Nite Only',
                        'Day Only',
                        'No Guests',
                        'Open Policy',
                      ],
                      onChanged: (v) =>
                          setState(() => _guestPolicy = v ?? 'Day/Nite Only'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? 200
                    : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Curfew:'),
                    Wrap(
                      spacing: 16,
                      children: [
                        _redRadio<bool>(
                          value: true,
                          groupValue: _noCurfew,
                          onChanged: (_) => setState(() => _noCurfew = true),
                          label: 'No Curfew',
                        ),
                        _redRadio<bool>(
                          value: false,
                          groupValue: _noCurfew,
                          onChanged: (_) => setState(() => _noCurfew = false),
                          label: 'With Curfew',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? 200
                    : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Subletting:'),
                    Wrap(
                      spacing: 16,
                      children: [
                        _redRadio<bool>(
                          value: true,
                          groupValue: _sublettingAllowed,
                          onChanged: (_) =>
                              setState(() => _sublettingAllowed = true),
                          label: 'Allowed',
                        ),
                        _redRadio<bool>(
                          value: false,
                          groupValue: _sublettingAllowed,
                          onChanged: (_) =>
                              setState(() => _sublettingAllowed = false),
                          label: 'Not Allowed',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? 200
                    : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Modifications:'),
                    Wrap(
                      spacing: 16,
                      children: [
                        _redRadio<bool>(
                          value: true,
                          groupValue: _modificationAllowed,
                          onChanged: (_) =>
                              setState(() => _modificationAllowed = true),
                          label: 'Allowed',
                        ),
                        _redRadio<bool>(
                          value: false,
                          groupValue: _modificationAllowed,
                          onChanged: (_) =>
                              setState(() => _modificationAllowed = false),
                          label: 'Not Allowed',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isLease) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE0C0)),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.gavel_outlined,
                    color: Color(0xFFE07820),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lease-only: early termination by the tenant forfeits '
                      'the security deposit unless agreed in writing. Renewal '
                      'requires 60 days prior notice.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: kLabelColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rent-only: either party may terminate with 30 days '
                      'written notice. Rent may be adjusted with 30 days '
                      'prior notice (subject to R.A. 9653).',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: kLabelColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TERMS & CONDITIONS  (per listing type)
  // ─────────────────────────────────────────────
  // Read-only by default — landlord taps "Customize" to edit each
  // clause inline. The edited terms are persisted via
  // listings.terms_override (JSONB array of strings) and rendered
  // verbatim by contract_view_screen at signing time.
  Widget _buildTermsAndConditionsSection() {
    final isLease = _listingType == 'lease';
    final terms = _termsOverride ?? defaultTermsForType(_listingType);
    final isCustomized = _termsOverride != null;

    return _sectionCard(
      title: isLease ? 'Lease Terms & Conditions' : 'Rental Terms & Conditions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isCustomized
                      ? 'You have customized the default terms. '
                            'Tenants will see exactly what is below.'
                      : 'These are the standard ${isLease ? 'lease' : 'rental'} '
                            'terms tenants will see and sign.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kHintColor,
                    height: 1.4,
                  ),
                ),
              ),
              if (isCustomized)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _termsOverride = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restored default terms.')),
                    );
                  },
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: kCoral,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < terms.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Text(
                    terms[i],
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: kLabelColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _openTermsEditor(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(isCustomized ? 'Edit Terms' : 'Customize Terms'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCoral,
                  side: const BorderSide(color: kCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isCustomized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kCoral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CUSTOMIZED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kCoral,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openTermsEditor() async {
    final base = _termsOverride ?? defaultTermsForType(_listingType);
    final controllers = base
        .map((t) => TextEditingController(text: t))
        .toList(growable: true);

    final result = await showDialog<List<String>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note, color: kCoral, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Customize Terms & Conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kSectionTitle,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx, null),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (int i = 0; i < controllers.length; i++) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controllers[i],
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    labelText: 'Clause ${i + 1}',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove clause',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: kRedSelected,
                                ),
                                onPressed: controllers.length <= 1
                                    ? null
                                    : () => setLocal(
                                        () => controllers.removeAt(i),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setLocal(
                              () => controllers.add(TextEditingController()),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Clause'),
                            style: TextButton.styleFrom(
                              foregroundColor: kCoral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, []),
                      child: const Text(
                        'Reset to Default',
                        style: TextStyle(color: kRedSelected),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx, null),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final edited = controllers
                            .map((c) => c.text.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        Navigator.pop(dialogCtx, edited);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCoral,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final c in controllers) {
      c.dispose();
    }

    if (!mounted || result == null) return;

    setState(() {
      // Empty list → user reset to defaults.
      _termsOverride = result.isEmpty ? null : result;
    });
  }

  // ─────────────────────────────────────────────
  // CONTRACT TEMPLATE SECTION
  // ─────────────────────────────────────────────
  // Three things the landlord can do here:
  //   1. Preview the current contract template (pre-filled with
  //      whatever they have entered on the form so far).
  //   2. Export it as a .txt file they can edit externally.
  //   3. Re-upload a modified file (PDF / DOC / DOCX / TXT) which
  //      then becomes the contract shipped to tenants.
  Widget _buildContractTemplateSection() {
    final isLease = _listingType == 'lease';
    final hasFile =
        _contractTemplateFile != null || _contractTemplateUrl != null;
    final fileLabel =
        _contractTemplateFile?.name ??
        _contractTemplateName ??
        (_contractTemplateUrl?.split('/').last ?? 'contract');

    return _sectionCard(
      title: 'Contract Template',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kCoral.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kCoral.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  isLease
                      ? Icons.assignment_turned_in_outlined
                      : Icons.event_repeat_rounded,
                  size: 16,
                  color: kCoral,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLease
                        ? 'Default: Residential Lease Agreement (fixed term).'
                        : 'Default: Month-to-Month Rental Agreement.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kLabelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Preview the template, export a copy you can edit on your '
            'computer, then re-upload the modified file to use it as the '
            'binding contract for this listing.',
            style: TextStyle(fontSize: 12, color: kHintColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _previewContractTemplate,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCoral,
                  side: const BorderSide(color: kCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportContractTemplate,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCoral,
                  side: const BorderSide(color: kCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _pickContractTemplateFile,
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(
                  hasFile ? 'Replace Uploaded File' : 'Upload Modified File',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCoral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          if (hasFile) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCDE9C2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF1A9E4A),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kLabelColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _contractTemplateFile != null
                              ? 'Will be uploaded when you save the listing.'
                              : 'Currently active for this listing.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: kHintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove uploaded file',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: kRedSelected,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _contractTemplateFile = null;
                        _contractTemplateUrl = null;
                        _contractTemplateName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build the strongly-typed input the PDF/text helpers consume.
  // Uses whatever the landlord has typed into the form so far —
  // any blanks render as `[…]` placeholders so the file remains
  // editable.
  ContractTemplateInput _composeContractInput() {
    final terms = _termsOverride ?? defaultTermsForType(_listingType);
    final propertyAddress = [
      _fullAddressCtrl.text,
      _streetAreaCtrl.text,
      _cityCtrl.text,
      _provinceCtrl.text,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    final startDate = _availableFrom != null
        ? _formatLongDate(_availableFrom!)
        : null;
    final endDate = _availableFrom != null && _listingType == 'lease'
        ? _formatLongDate(_addLeaseTerm(_availableFrom!, _leaseTerm))
        : null;
    final agreementDate = _formatLongDate(DateTime.now());
    return ContractTemplateInput(
      listingType: _listingType,
      terms: terms,
      landlordName: _hostNameCtrl.text,
      propertyTitle: _listingTitleCtrl.text,
      propertyAddress: propertyAddress,
      propertyType: _propertyType,
      leaseStartDate: startDate,
      leaseEndDate: endDate,
      leaseDuration: _listingType == 'lease' ? _leaseTerm : null,
      monthlyRent: _monthlyRentCtrl.text,
      securityDeposit: _securityDepositCtrl.text,
      advancePayment: _advancePaymentCtrl.text,
      agreementDate: agreementDate,
    );
  }

  static const List<String> _kMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatLongDate(DateTime d) =>
      '${_kMonthNames[d.month - 1]} ${d.day}, ${d.year}';

  // Approximate lease end date by parsing "12 months", "6 months", etc.
  // and adding the month count to the start date.
  DateTime _addLeaseTerm(DateTime start, String term) {
    final match = RegExp(r'(\d+)').firstMatch(term);
    final months = int.tryParse(match?.group(1) ?? '') ?? 12;
    return DateTime(start.year, start.month + months, start.day);
  }

  Future<void> _previewContractTemplate() async {
    if (!mounted) return;
    final input = _composeContractInput();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: kCoral,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Contract Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                tooltip: 'Copy text',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: buildContractTemplateText(input)),
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) async {
              final doc = await buildContractPdf(input);
              return doc.save();
            },
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName:
                '${_listingType}_contract_${DateTime.now().millisecondsSinceEpoch}.pdf',
          ),
        ),
      ),
    );
  }

  Future<void> _exportContractTemplate() async {
    try {
      final input = _composeContractInput();
      final doc = await buildContractPdf(input);
      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${_listingType}_contract_$stamp.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      // Offer Share (system share sheet — saves to Downloads, email,
      // etc.) and Open (launch the local copy in a PDF viewer).
      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: kCoral),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Contract PDF ready',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kSectionTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    fileName,
                    style: const TextStyle(fontSize: 12, color: kHintColor),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share, color: kCoral),
                  title: const Text('Share / Save to device'),
                  subtitle: const Text(
                    'Open the system share sheet to save to Downloads, '
                    'email, or another app.',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await Printing.sharePdf(bytes: bytes, filename: fileName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new, color: kCoral),
                  title: const Text('Open in PDF viewer'),
                  subtitle: Text(
                    file.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final uri = Uri.file(file.path);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined, color: kCoral),
                  title: const Text('Print'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name: fileName,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _pickContractTemplateFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null && file.path == null) return;
      setState(() {
        _contractTemplateFile = file;
        // A new local file supersedes any previously-saved remote file.
        _contractTemplateUrl = null;
        _contractTemplateName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick file: $e')));
    }
  }

  Widget _buildHostInformationSection() => _sectionCard(
    title: 'Host Information',
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 200
              : double.infinity,
          child: _buildTextFieldColumn(
            'Host Name:',
            _hostNameCtrl,
            'Enter Host Name',
          ),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 200
              : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Role:'),
              _dropdown(
                hint: 'Select role',
                value: _hostRole,
                items: ['Owner', 'Agent', 'Property Manager'],
                onChanged: (v) => setState(() => _hostRole = v),
              ),
            ],
          ),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 200
              : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Response Time:'),
              _dropdown(
                hint: 'Within 1 Hour',
                value: _responseTime,
                items: [
                  'Within 1 Hour',
                  'Within 3 Hours',
                  'Within 6 Hours',
                  'Within 24 Hours',
                ],
                onChanged: (v) =>
                    setState(() => _responseTime = v ?? 'Within 1 Hour'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _pickVerificationDoc() async {
    final f = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (f != null) setState(() => _verificationDoc = f);
  }

  Widget _buildPropertyVerificationSection() => _sectionCard(
    title: 'Property Verification',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Upload a proof of ownership (e.g. land title, '
                'tax declaration, or utility bill).',
                style: TextStyle(fontSize: 12, color: kHintColor),
              ),
            ),
            if (_listingVerified) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VxrTokens.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: VxrTokens.accent),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 11,
                        color: VxrTokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_verificationDocUrl?.isNotEmpty ?? false) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VxrTokens.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 14,
                      color: VxrTokens.warning,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pending Review',
                      style: TextStyle(
                        fontSize: 11,
                        color: VxrTokens.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickVerificationDoc,
          child: DashedBorderBox(
            child: Container(
              height: 110,
              width: double.infinity,
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _verificationDoc != null ||
                            (_verificationDocUrl?.isNotEmpty ?? false)
                        ? Icons.description
                        : Icons.upload_file_outlined,
                    size: 32,
                    color:
                        _verificationDoc != null ||
                            (_verificationDocUrl?.isNotEmpty ?? false)
                        ? VxrTokens.accent
                        : const Color(0xFF999999),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _verificationDoc != null
                        ? _verificationDoc!.name
                        : (_verificationDocUrl?.isNotEmpty ?? false)
                        ? 'Document on file'
                        : 'Upload Verification Document',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          _verificationDoc != null ||
                              (_verificationDocUrl?.isNotEmpty ?? false)
                          ? VxrTokens.accent
                          : kLabelColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to select an image (required for new listings)',
                    style: TextStyle(fontSize: 12, color: kHintColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMediaUploadSection() => _sectionCard(
    title: 'Media Upload',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload images and media for your listing',
          style: TextStyle(fontSize: 12, color: kHintColor),
        ),
        const SizedBox(height: 14),

        // Property Images — open the image manager
        GestureDetector(
          onTap: _openImageManager,
          child: DashedBorderBox(
            child: Container(
              height: 120,
              width: double.infinity,
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 32,
                    color: _propertyImages.isEmpty
                        ? const Color(0xFF999999)
                        : VxrTokens.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _propertyImages.isEmpty
                        ? 'Add Property Images'
                        : '${_propertyImages.length} photo${_propertyImages.length == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _propertyImages.isEmpty
                          ? kLabelColor
                          : VxrTokens.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _propertyImages.isEmpty
                        ? 'Tap to upload or capture photos'
                        : 'Tap to manage photos',
                    style: const TextStyle(fontSize: 12, color: kHintColor),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Thumbnails preview
        if (_propertyImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 65,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _propertyImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 65,
                  height: 65,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: XFileImage(
                          file: _propertyImages[index],
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage('property', index),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Cover Photo section (kept separate)
        _coverPhotoUploadBox(),

        const SizedBox(height: 16),

        // ── 360° Panorama Section ──
        const Divider(height: 1, color: kBorderColor),
        const SizedBox(height: 14),
        const Text(
          '360° Panorama Images',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kLabelColor,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add immersive 360° panorama views of your property',
          style: TextStyle(fontSize: 12, color: kHintColor),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _openPanoramaManager,
          child: DashedBorderBox(
            child: Container(
              height: 120,
              width: double.infinity,
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.view_in_ar,
                    size: 32,
                    color: _media360Rooms.isEmpty
                        ? const Color(0xFF999999)
                        : VxrTokens.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _media360Rooms.isEmpty
                        ? 'Add 360° Room Tour'
                        : '${_media360Rooms.length} room${_media360Rooms.length == 1 ? '' : 's'} added',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _media360Rooms.isEmpty
                          ? kLabelColor
                          : VxrTokens.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _media360Rooms.isEmpty
                        ? 'Tap to capture 360° panoramas'
                        : 'Tap to manage room panoramas',
                    style: const TextStyle(fontSize: 12, color: kHintColor),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Room panorama cards preview
        if (_media360Rooms.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 65,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _media360Rooms.length,
              itemBuilder: (context, index) {
                final room = _media360Rooms[index];
                return Container(
                  width: 90,
                  height: 65,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 90,
                          height: 65,
                          child: room.isLocal
                              ? Image.file(
                                  File(room.localFile!.path),
                                  width: 90,
                                  height: 65,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.view_in_ar,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Image.network(
                                  room.url ?? '',
                                  width: 90,
                                  height: 65,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.view_in_ar,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Room label overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            room.roomLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // 360 icon overlay
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: kCoral.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.view_in_ar,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage('360', index),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    ),
  );

  // Open the full image manager screen
  Future<void> _openImageManager() async {
    final result = await Navigator.push<List<ListingImageItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => ListingImageManagerScreen(
          listingId: widget.existingListingId,
          initialLocalImages: _propertyImages.isNotEmpty
              ? _propertyImages
              : null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _propertyImages = result
            .where((item) => item.isLocal)
            .map((item) => item.localFile!)
            .toList();
      });
    }
  }

  // Open the panorama manager screen
  Future<void> _openPanoramaManager() async {
    final result = await Navigator.push<List<RoomPanoramaItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => PanoramaManagerScreen(
          listingId: widget.existingListingId,
          initialRooms: _media360Rooms.isNotEmpty ? _media360Rooms : null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _media360Rooms = result;
      });
    }
  }

  // Helper Methods for Image Upload
  Future<void> _pickCoverPhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _coverPhoto = picked);
  }

  void _removeImage(String type, int index) => setState(() {
    if (type == 'property') {
      _propertyImages.removeAt(index);
    } else {
      _media360Rooms.removeAt(index);
    }
  });

  // Helper Widget Builders
  Widget _buildTwoColumnRow({required Widget child1, required Widget child2}) =>
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width > 600
                ? (MediaQuery.of(context).size.width - 80) / 2
                : double.infinity,
            child: child1,
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width > 600
                ? (MediaQuery.of(context).size.width - 80) / 2
                : double.infinity,
            child: child2,
          ),
        ],
      );

  Widget _buildThreeColumnRow({
    required Widget child1,
    required Widget child2,
    required Widget child3,
  }) => Wrap(
    spacing: 10,
    runSpacing: 12,
    children: [
      SizedBox(
        width: MediaQuery.of(context).size.width > 600
            ? (MediaQuery.of(context).size.width - 100) / 3
            : double.infinity,
        child: child1,
      ),
      SizedBox(
        width: MediaQuery.of(context).size.width > 600
            ? (MediaQuery.of(context).size.width - 100) / 3
            : double.infinity,
        child: child2,
      ),
      SizedBox(
        width: MediaQuery.of(context).size.width > 600
            ? (MediaQuery.of(context).size.width - 100) / 3
            : double.infinity,
        child: child3,
      ),
    ],
  );

  Widget _buildTextFieldColumn(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(hint),
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );

  Widget _buildDropdownColumn(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      _dropdown(hint: '', value: value, items: items, onChanged: onChanged),
    ],
  );

  Widget _buildPriceField(String label, TextEditingController controller) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('').copyWith(
              prefixText: '₱',
              prefixStyle: const TextStyle(color: kLabelColor, fontSize: 13),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      );

  Widget _buildSquareMeterField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('Square Meter:'),
      TextField(
        controller: _squareMeterCtrl,
        keyboardType: TextInputType.number,
        decoration: _inputDecoration('e.g. 45').copyWith(
          suffixText: 'm²',
          suffixStyle: const TextStyle(
            color: kLabelColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );

  Widget _coverPhotoUploadBox() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: _pickCoverPhoto,
        child: DashedBorderBox(
          child: Container(
            height: 100,
            width: double.infinity,
            color: Colors.transparent,
            child: _coverPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: XFileImage(
                      file: _coverPhoto!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_outlined,
                        size: 26,
                        color: Color(0xFF999999),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Cover Photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kLabelColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Click to select',
                        style: TextStyle(fontSize: 11, color: kHintColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      if (_coverPhoto != null) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _coverPhoto!.name,
                style: const TextStyle(fontSize: 11, color: kHintColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _coverPhoto = null),
              child: const Icon(
                Icons.delete_outline,
                size: 16,
                color: kRedSelected,
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _buildBottomButtons() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: VxrSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: VxrPrimaryButton(
            label: widget.existingListingId != null
                ? 'Save Changes'
                : 'Create Listing',
            loading: _isSaving,
            onPressed: _saveToSupabase,
          ),
        ),
      ],
    ),
  );

  Future<void> _saveToSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in first')));
      }
      return;
    }

    // New listings must include a proof-of-ownership document.
    final isNewListing = widget.existingListingId == null;
    if (isNewListing && _verificationDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload a verification document (Property Verification section).',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload property verification document if a new file was picked.
      String? verificationDocPath = _verificationDocUrl;
      if (_verificationDoc != null) {
        final bytes = await _verificationDoc!.readAsBytes();
        verificationDocPath = await uploadListingVerificationDoc(
          bytes: bytes,
          fileName: _verificationDoc!.name,
        );
      }

      // For existing listings: upload cover photo now (real ID is known).
      // For NEW listings: defer the upload until after insertListing() so
      // the file goes into the correct listingId/ folder instead of a
      // temporary path.
      String? coverPhotoPath;
      if (_coverPhoto != null && widget.existingListingId != null) {
        final bytes = await _coverPhoto!.readAsBytes();
        final ext = _coverPhoto!.name.split('.').last;
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storagePath = '${widget.existingListingId}/$fileName';
        await Supabase.instance.client.storage
            .from('listing-images')
            .uploadBinary(storagePath, bytes);
        coverPhotoPath = storagePath;
      }

      // Upload modified contract template (PDF/DOC/etc.) if the
      // landlord picked a new one. Stored in a dedicated bucket so
      // the listing-images RLS doesn't have to worry about
      // non-image MIME types.
      String? contractTemplatePath;
      String? contractTemplateName;
      if (_contractTemplateFile != null) {
        try {
          final picked = _contractTemplateFile!;
          final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
          final ext = picked.extension ?? 'bin';
          final tempId =
              widget.existingListingId ??
              'temp_${DateTime.now().millisecondsSinceEpoch}';
          final fileName =
              'contract_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final storagePath = '$tempId/$fileName';
          await Supabase.instance.client.storage
              .from('listing-contracts')
              .uploadBinary(storagePath, bytes);
          contractTemplatePath = storagePath;
          contractTemplateName = picked.name;
        } catch (e) {
          debugPrint('Contract template upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Contract upload failed (continuing without): $e',
                ),
              ),
            );
          }
        }
      } else if (_contractTemplateUrl != null) {
        // Editing an existing listing and the landlord did not
        // touch the file — keep what's already there.
        contractTemplatePath = _contractTemplateUrl;
        contractTemplateName = _contractTemplateName;
      }

      final monthlyRent =
          double.tryParse(
            _monthlyRentCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;

      // Core listings table
      final core = <String, dynamic>{
        'landlord_id': userId,
        'title': _listingTitleCtrl.text.isEmpty
            ? 'Untitled Listing'
            : _listingTitleCtrl.text,
        'description': _aboutPlaceCtrl.text.isEmpty
            ? null
            : _aboutPlaceCtrl.text,
        'property_type': _propertyType,
        'listing_type': _listingType,
        'status': _isActive ? 'active' : 'inactive',
        'cover_photo_url': ?coverPhotoPath,
        // Always write these (including nulls) so removing an
        // uploaded contract or resetting custom terms persists.
        'contract_template_url': contractTemplatePath,
        'contract_template_name': contractTemplateName,
        'terms_override': _termsOverride,
        // Verification — admin must approve via the web dashboard.
        // is_verified stays false until an admin sets it to true.
        'verification_doc_url': verificationDocPath,
        'verification_submitted_at':
            verificationDocPath != null && _verificationDoc != null
            ? DateTime.now().toIso8601String()
            : null,
        'is_verified': false,
      };

      // listing_locations
      final location = <String, dynamic>{
        'full_address': _fullAddressCtrl.text.isEmpty
            ? null
            : _fullAddressCtrl.text,
        'barangay': _streetAreaCtrl.text.isEmpty ? null : _streetAreaCtrl.text,
        'city': _cityCtrl.text.isEmpty ? null : _cityCtrl.text,
        'province': _provinceCtrl.text.isEmpty ? null : _provinceCtrl.text,
        'postal_code': _postalCodeCtrl.text.isEmpty
            ? null
            : _postalCodeCtrl.text,
        'latitude': _mapPosition.latitude,
        'longitude': _mapPosition.longitude,
      };

      // listing_details
      final details = <String, dynamic>{
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'max_occupants': int.tryParse(_maxOccupantsCtrl.text),
        'square_meters': double.tryParse(_squareMeterCtrl.text),
        'furnishing': _furnishing,
        'has_balcony': _amenities['Balcony'] ?? false,
        'has_storage': _amenities['Storage'] ?? false,
      };

      // listing_amenities
      final amenities = <String, dynamic>{
        'has_aircon': _amenities['Air Conditioning'] ?? false,
        'has_refrigerator': _amenities['Refrigerator'] ?? false,
        'has_washing_machine': _amenities['Washing Machine'] ?? false,
        'has_water_heater': _amenities['Water Heater'] ?? false,
        'has_stove': _amenities['Stove'] ?? false,
        'has_cabinet': _amenities['Cabinet'] ?? false,
        'has_bed': _amenities['Bed'] ?? false,
      };

      // listing_utilities
      final utilities = <String, dynamic>{
        'with_water': _withWater,
        'with_electricity': _withElectricity,
        'with_internet': _withInternet,
        'with_parking': _withParking,
      };

      // listing_building_features
      final buildingFeatures = <String, dynamic>{
        'has_security': _hasSecurity,
        'has_elevator': _hasElevator,
        'has_backup_power': _hasBackupPower,
        'has_pool': _hasPool,
        'has_gym': _hasGym,
        'has_laundry_area': _hasLaundryArea,
        'has_function_hall': _hasFunctionHall,
        'has_playground': _hasPlayground,
      };

      // listing_financials
      final financials = <String, dynamic>{
        'monthly_rent': monthlyRent,
        'security_deposit':
            double.tryParse(
              _securityDepositCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
            ) ??
            0,
        'advance_payment':
            double.tryParse(
              _advancePaymentCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
            ) ??
            0,
        'payment_terms': _paymentTerms,
        'payment_method': _paymentMethod,
      };

      // listing_availability
      final availability = <String, dynamic>{
        'is_immediate': _isImmediate,
        'available_from': _availableFrom?.toIso8601String(),
        'lease_term': _leaseTerm,
      };

      // listing_policies
      final policies = <String, dynamic>{
        'pets_allowed': _petsAllowed,
        'smoking_allowed': _smokingAllowed,
        'no_curfew': _noCurfew,
        'subletting_allowed': _sublettingAllowed,
        'guest_policy': _guestPolicy,
        'modification_allowed': _modificationAllowed,
      };

      // listing_requirements
      final requirements = <String, dynamic>{
        'requires_proof_of_income': true,
        'requires_employment_cert': true,
        'requires_valid_id': true,
        'requires_references': false,
      };

      // listing_host_info
      final hostInfo = <String, dynamic>{
        'host_name': _hostNameCtrl.text.isEmpty ? null : _hostNameCtrl.text,
        'host_role': _hostRole,
        'response_time': _responseTime,
      };

      bool success;
      String? listingId;

      if (widget.existingListingId != null) {
        // UPDATE across all normalized tables
        success = await updateListing(
          listingId: widget.existingListingId!,
          core: core,
          location: location,
          details: details,
          amenities: amenities,
          utilities: utilities,
          buildingFeatures: buildingFeatures,
          financials: financials,
          availability: availability,
          policies: policies,
          requirements: requirements,
          hostInfo: hostInfo,
        );
        listingId = widget.existingListingId;
      } else {
        // INSERT across all normalized tables
        listingId = await insertListing(
          core: core,
          location: location,
          details: details,
          amenities: amenities,
          utilities: utilities,
          buildingFeatures: buildingFeatures,
          financials: financials,
          availability: availability,
          policies: policies,
          requirements: requirements,
          hostInfo: hostInfo,
        );
        success = listingId != null;
        // Owning a listing flips the landlord capability flag.
        // `role` stays as-is so the user can still act as a tenant.
        if (success) {
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({'is_landlord': true})
                .eq('id', userId);
          } catch (e) {
            debugPrint('Promote to landlord failed: $e');
          }
        }
      }

      // Upload cover photo for NEW listings (deferred — real listingId now known).
      // For edits, the upload already happened above.
      if (success &&
          listingId != null &&
          _coverPhoto != null &&
          widget.existingListingId == null) {
        try {
          final bytes = await _coverPhoto!.readAsBytes();
          final ext = _coverPhoto!.name.split('.').last;
          final fileName =
              'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final storagePath = '$listingId/$fileName';
          await Supabase.instance.client.storage
              .from('listing-images')
              .uploadBinary(storagePath, bytes);
          await Supabase.instance.client
              .from('listings')
              .update({'cover_photo_url': storagePath})
              .eq('id', listingId);
        } catch (e) {
          debugPrint('Cover photo upload (new listing) failed: $e');
        }
      }

      // Upload property images
      if (success && listingId != null && _propertyImages.isNotEmpty) {
        final storagePaths = <String>[];
        for (int i = 0; i < _propertyImages.length; i++) {
          final img = _propertyImages[i];
          final bytes = await img.readAsBytes();
          final ext = img.name.split('.').last;
          final path =
              '$listingId/img_${i}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          try {
            await Supabase.instance.client.storage
                .from('listing-images')
                .uploadBinary(path, bytes);
            storagePaths.add(path);
          } catch (e) {
            debugPrint('Image upload failed: $e');
          }
        }
        if (storagePaths.isNotEmpty) {
          try {
            await saveListingImages(
              listingId,
              storagePaths,
              imageType: 'normal',
              uploadSource: 'upload',
            );
          } catch (e) {
            debugPrint('saveListingImages ERROR: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Listing saved, but images could not be recorded in the database: $e\n'
                    'Please open the listing and re-upload images from Manage Photos.',
                  ),
                  backgroundColor: VxrTokens.warning,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          }
          // Bug fix: when no explicit cover photo was selected,
          // use the first uploaded property image as the cover.
          if (_coverPhoto == null) {
            try {
              await Supabase.instance.client
                  .from('listings')
                  .update({'cover_photo_url': storagePaths.first})
                  .eq('id', listingId);
            } catch (e) {
              debugPrint('cover_photo_url update failed: $e');
            }
          }
        }
      }

      // Upload 360° panorama images
      if (success && listingId != null && _media360Rooms.isNotEmpty) {
        final localRooms = _media360Rooms.where((r) => r.isLocal).toList();
        for (int i = 0; i < localRooms.length; i++) {
          final room = localRooms[i];
          final bytes = await room.localFile!.readAsBytes();
          final ext = room.localFile!.name.split('.').last;
          final path =
              '$listingId/pano_${i}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          try {
            await Supabase.instance.client.storage
                .from('listing-images')
                .uploadBinary(path, bytes);
            await savePanoramaImage(
              listingId: listingId,
              storagePath: path,
              roomLabel: room.roomLabel,
              uploadSource: room.uploadSource,
              sortOrder: _media360Rooms.indexOf(room),
            );
          } catch (e) {
            debugPrint('Panorama upload failed: $e');
          }
        }
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.existingListingId != null
                    ? 'Listing updated!'
                    : 'Listing created!',
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save listing')),
          );
        }
      }
    } catch (e) {
      debugPrint('_saveToSupabase ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ─────────────────────────────────────────────
// DASHED BORDER BOX
// ─────────────────────────────────────────────
class DashedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  const DashedBorderBox({
    super.key,
    required this.child,
    this.color = const Color(0xFFCCCCCC),
    this.strokeWidth = 1.5,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(
      color: color,
      strokeWidth: strokeWidth,
      dashWidth: dashWidth,
      dashSpace: dashSpace,
      borderRadius: borderRadius,
    ),
    child: child,
  );
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    canvas.drawPath(_createDashedPath(path), paint);
  }

  Path _createDashedPath(Path source) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// CROSS-PLATFORM IMAGE WIDGET
// ─────────────────────────────────────────────
class XFileImage extends StatefulWidget {
  final XFile file;
  final double? width;
  final double? height;
  final BoxFit fit;

  const XFileImage({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<XFileImage> createState() => _XFileImageState();
}

class _XFileImageState extends State<XFileImage> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytesFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      }
      return Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFEEEEEE),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kCoral),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
// MAP ADDRESS PICKER (for listing location)
// ─────────────────────────────────────────────
class _ListingMapAddressPicker extends StatefulWidget {
  final LatLng initialPosition;

  const _ListingMapAddressPicker({required this.initialPosition});

  @override
  State<_ListingMapAddressPicker> createState() =>
      _ListingMapAddressPickerState();
}

class _ListingMapAddressPickerState extends State<_ListingMapAddressPicker> {
  late LatLng _selectedPosition;
  String _address = 'Move the map to pick a location';
  bool _loadingAddress = false;
  Timer? _debounceTimer;

  // Parsed address components
  String _city = '';
  String _province = '';
  String _barangay = '';
  String _postalCode = '';

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _reverseGeocode(_selectedPosition);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onCameraIdle() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocode(_selectedPosition);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${pos.latitude},${pos.longitude}'
        '&key=$_mapsApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          _address = result['formatted_address'] ?? 'Unknown';
          _parseAddressComponents(
            result['address_components'] as List<dynamic>,
          );
        } else {
          _address = 'No address found for this location';
        }
      } else {
        _address = 'Could not determine address';
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      _address = 'Could not determine address';
    }
    if (mounted) setState(() => _loadingAddress = false);
  }

  void _parseAddressComponents(List<dynamic> components) {
    _city = '';
    _province = '';
    _barangay = '';
    _postalCode = '';

    for (final comp in components) {
      final types = (comp['types'] as List<dynamic>).cast<String>();
      final longName = comp['long_name']?.toString() ?? '';

      if (types.contains('locality')) {
        _city = longName;
      } else if (types.contains('administrative_area_level_2') &&
          _city.isEmpty) {
        _city = longName;
      } else if (types.contains('administrative_area_level_1')) {
        _province = longName;
      } else if (types.contains('sublocality_level_1') ||
          types.contains('sublocality')) {
        _barangay = longName;
      } else if (types.contains('neighborhood') && _barangay.isEmpty) {
        _barangay = longName;
      } else if (types.contains('postal_code')) {
        _postalCode = longName;
      }
    }
  }

  void _confirmSelection() {
    Navigator.pop(context, {
      'full_address': _address,
      'city': _city,
      'province': _province,
      'barangay': _barangay,
      'postal_code': _postalCode,
      'lat': _selectedPosition.latitude.toString(),
      'lng': _selectedPosition.longitude.toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pick Property Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 16,
            ),
            onCameraMove: (position) {
              _selectedPosition = position.target;
            },
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Center pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_pin, size: 48, color: kCoral),
            ),
          ),
          // Address bar at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: kCoral, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _loadingAddress
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kCoral,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Getting address...',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              )
                            : Text(
                                _address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  // Parsed fields preview
                  if (!_loadingAddress &&
                      (_city.isNotEmpty || _province.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VxrTokens.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (_city.isNotEmpty)
                            _addressDetailRow('City', _city),
                          if (_province.isNotEmpty)
                            _addressDetailRow('Province', _province),
                          if (_barangay.isNotEmpty)
                            _addressDetailRow('Barangay', _barangay),
                          if (_postalCode.isNotEmpty)
                            _addressDetailRow('Postal Code', _postalCode),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadingAddress ? null : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCoral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _addressDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
