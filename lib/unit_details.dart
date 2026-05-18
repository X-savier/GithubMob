import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/vxr_theme.dart';
import 'theme/vxr_widgets.dart';
import 'chat_thread_screen.dart';
import 'contract_view_screen.dart';
import 'panorama_tour_viewer.dart';
import 'property_data.dart';
import 'rental_application.dart';
import 'verification_screen.dart';

class UnitDetailsScreen extends StatefulWidget {
  final Property property;

  const UnitDetailsScreen({
    super.key,
    required this.property,
  });

  @override
  State<UnitDetailsScreen> createState() => _UnitDetailsScreenState();
}

class _UnitDetailsScreenState extends State<UnitDetailsScreen> {
  Map<String, dynamic>? _details;
  Map<String, dynamic>? _landlord;
  List<String> _images = [];
  List<String> _amenities = [];
  List<TourRoom> _panoramaRooms = [];
  bool _isLoading = true;
  bool _openingChat = false;
  bool _contractClosed = false;
  ({String id, String status})? _myApp;

  Property get p => widget.property;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _refreshApplicationStatus();
  }

  Future<void> _refreshApplicationStatus() async {
    if (p.id == null) return;
    final res = await getMyApplicationForListing(p.id!);
    bool contractClosed = false;
    if (res != null && res.status == 'approved') {
      // Check if the contract tied to this application has already been closed.
      // A closed/archived contract means the tenancy ended — let the tenant apply again.
      try {
        final contract = await Supabase.instance.client
            .from('contract')
            .select('status')
            .eq('application_id', res.id)
            .maybeSingle();
        final cs = contract?['status']?.toString() ?? '';
        contractClosed = cs == 'closed' || cs == 'archived';
      } catch (_) {}
    }
    if (mounted) setState(() { _myApp = res; _contractClosed = contractClosed; });
  }

  /// Sticky bottom CTA bar — Variation B treatment: surface bg, top border,
  /// optional 360° tour button (flex 1) + the apply / contract CTA (flex 2).
  Widget _buildStickyCta() {
    final t = VxrTheme.of(context);
    final isOwner =
        p.landlordId == Supabase.instance.client.auth.currentUser?.id;
    final hasTour = _panoramaRooms.isNotEmpty;

    Widget? tourButton;
    if (hasTour) {
      tourButton = VxrSecondaryButton(
        label: '360° Tour',
        icon: Icons.view_in_ar,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PanoramaTourViewer(
                rooms: _panoramaRooms,
                listingTitle: p.title,
              ),
            ),
          );
        },
      );
    }

    final actionButton = isOwner ? null : _buildApplyOrContractCta();

    final children = <Widget>[];
    if (tourButton != null) {
      children.add(Expanded(child: tourButton));
    }
    if (actionButton != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 10));
      children.add(Expanded(flex: 2, child: actionButton));
    }
    if (children.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(children: children),
      ),
    );
  }

  Widget _buildApplyOrContractCta() {
    final t = VxrTheme.of(context);
    final status = _myApp?.status;

    switch (status) {
      case 'approved' when !_contractClosed:
        return VxrPrimaryButton(
          label: 'View Contract',
          icon: Icons.description_outlined,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContractViewScreen(
                  applicationId: _myApp!.id,
                  listingId: p.id!,
                  landlordId: p.landlordId ?? '',
                ),
              ),
            );
            _refreshApplicationStatus();
          },
        );
      case 'pending':
        return Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(VxrTokens.radius),
            border: Border.all(color: t.border),
          ),
          child: Text(
            'Application Pending',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
            ),
          ),
        );
      case 'rejected':
        return VxrPrimaryButton(
          label: 'Apply Again',
          onPressed: () => _openApplicationForm(),
        );
      default:
        return VxrPrimaryButton(
          label: 'Apply Now',
          onPressed: () => _openApplicationForm(),
        );
    }
  }

  Future<void> _openApplicationForm() async {
    if (p.id == null) return;
    // Guard: listing must be active.
    final listingStatus = _details?['status']?.toString() ?? 'active';
    if (listingStatus != 'active') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This listing is no longer accepting applications.'),
        ),
      );
      return;
    }
    final canApply = await ensureVerifiedToApply(context);
    if (!canApply || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RentalApplicationScreen(listingId: p.id!),
      ),
    );
    _refreshApplicationStatus();
  }

  Future<void> _loadDetails() async {
    if (p.id == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      fetchListingDetails(p.id!),
      fetchListingImages(p.id!),
      fetchListingAmenities(p.id!),
      fetchPanoramaImages(p.id!),
    ]);

    if (mounted) {
      setState(() {
        _details = results[0] as Map<String, dynamic>?;
        _images = results[1] as List<String>;
        _amenities = results[2] as List<String>;
        _details ??= <String, dynamic>{};
        // Build panorama room list
        final panoRecords = results[3] as List<Map<String, dynamic>>;
        _panoramaRooms = panoRecords.map((rec) {
          return TourRoom(
            label: rec['room_label']?.toString() ?? 'Room',
            imageUrl: buildStorageUrl(rec['url'] ?? ''),
          );
        }).toList();
        // If no extra images, use the cover photo
        if (_images.isEmpty && p.image.isNotEmpty) {
          _images = [p.image];
        }
        _isLoading = false;
      });
    }

    // Pull listing_type directly from the `listings` table so the
    // For Rent / For Lease badge always reflects the source-of-truth value.
    try {
      final row = await Supabase.instance.client
          .from('listings')
          .select('listing_type')
          .eq('id', p.id!)
          .maybeSingle();
      if (mounted && row != null && row['listing_type'] != null) {
        setState(() {
          _details ??= <String, dynamic>{};
          _details!['listing_type'] = row['listing_type'];
        });
      }
    } catch (e) {
      debugPrint('unit_details listing_type ERROR: $e');
    }

    // Pull the landlord's profile (full_name + avatar_url) for the
    // Hosted By card. Lives in `profiles`, keyed by listings.landlord_id.
    final landlordId = p.landlordId;
    if (landlordId != null && landlordId.isNotEmpty) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .eq('id', landlordId)
            .maybeSingle();
        if (mounted && profile != null) {
          setState(() => _landlord = Map<String, dynamic>.from(profile));
        }
      } catch (e) {
        debugPrint('unit_details landlord profile ERROR: $e');
      }
    }
  }

  Future<void> _openChatWithLandlord() async {
    if (_openingChat) return;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final landlordId = p.landlordId;
    final listingId = p.id;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to message.')),
      );
      return;
    }
    if (landlordId == null || landlordId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No landlord on this listing.')),
      );
      return;
    }
    if (me == landlordId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That's your own listing.")),
      );
      return;
    }

    setState(() => _openingChat = true);
    final messenger = ScaffoldMessenger.of(context);
    final convId = await getOrCreateConversation(
      landlordId: landlordId,
      tenantId: me,
      listingId: listingId,
    );
    if (!mounted) return;
    setState(() => _openingChat = false);

    if (convId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open chat. Try again.')),
      );
      return;
    }

    final name =
        (_landlord?['full_name']?.toString().trim() ?? '');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationId: convId,
          otherName: name.isEmpty ? 'Property Host' : name,
          otherAvatarUrl:
              _landlord?['avatar_url']?.toString() ?? '',
          listingTitle: p.title,
        ),
      ),
    );
  }

  String _val(String key, [String fallback = '\u2014']) {
    return _details?[key]?.toString() ?? fallback;
  }

  bool _boolVal(String key) => _details?[key] == true;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: VxrTokens.bg,
        bottomNavigationBar: _isLoading ? null : _buildStickyCta(),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: VxrTokens.accent,
                  ),
                )
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      // Image Carousel
                      SliverToBoxAdapter(
                        child: _buildImageCarousel(),
                      ),
                      // Title, Price, Specs
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildListingTypeBadge(),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _details?['full_address']?.toString() ??
                                          p.location,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Price
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p.price,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: VxrTokens.accent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Specs bar
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildSpecItem(
                                            Icons.bed,
                                            '${p.beds}',
                                            p.beds == 1
                                                ? 'Bedroom'
                                                : 'Bedrooms'),
                                      ),
                                      Expanded(
                                        child: _buildSpecItem(
                                            Icons.bathtub_outlined,
                                            p.baths,
                                            p.baths == '1'
                                                ? 'Bathroom'
                                                : 'Bathrooms'),
                                      ),
                                      Expanded(
                                        child: _buildSpecItem(
                                            Icons.square_foot,
                                            p.area,
                                            'Floor Area'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tab bar
                      SliverPersistentHeader(
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            labelColor: VxrTokens.accent,
                            unselectedLabelColor: VxrTokens.textMuted,
                            indicatorColor: VxrTokens.accent,
                            indicatorWeight: 2,
                            labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w700),
                            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            tabs: const [
                              Tab(text: "Details"),
                              Tab(text: "Amenities"),
                              Tab(text: "Location"),
                            ],
                          ),
                        ),
                        pinned: true,
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: [
                      _buildDetailsTab(),
                      _buildAmenitiesTab(),
                      _buildLocationTab(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // --- Image Carousel ---
  Widget _buildImageCarousel() {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          child: _images.isEmpty
              ? _imagePlaceholder(300)
              : PageView.builder(
                  itemCount: _images.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FullScreenImageViewer(
                              images: _images,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(25),
                        ),
                        child: _buildImage(_images[index], 300),
                      ),
                    );
                  },
                ),
        ),
        // Gradient overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: _circleButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // Share button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 60,
          child: _circleButton(
            icon: Icons.share_outlined,
            onPressed: () {},
          ),
        ),
        // Favorite button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: _circleButton(
            icon: Icons.favorite_border,
            onPressed: () {},
          ),
        ),
        // Image counter
        if (_images.length > 1)
          Positioned(
            bottom: 16,
            right: 20,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${_images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        // Dot indicators
        if (_images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == index ? 10 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  int _currentImageIndex = 0;

  // --- Details Tab ---
  Widget _buildDetailsTab() {
    final description = _details?['description']?.toString() ??
        'No description available.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About
          const Text("About This Place",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Property Features
          const Text("Property Features",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _featureCard([
            _featureRow(
                Icons.apartment, "Property Type", _val('property_type')),
            _featureRow(Icons.chair, "Furnishing", _val('furnishing')),
            if (_details?['floor_number'] != null)
              _featureRow(Icons.stairs, "Floor Level",
                  'Floor ${_val('floor_number')}'),
            if (_details?['total_floors'] != null)
              _featureRow(Icons.layers, "Total Floors", _val('total_floors')),
            if (_details?['flooring_type'] != null)
              _featureRow(
                  Icons.straighten, "Flooring", _val('flooring_type')),
            if (_details?['year_built'] != null)
              _featureRow(Icons.calendar_today, "Year Built",
                  _val('year_built')),
            _featureRow(
                Icons.calendar_month,
                "Available",
                _boolVal('is_immediate')
                    ? 'Available Now'
                    : _val('available_from', 'Contact for date')),
            if (_details?['max_occupants'] != null)
              _featureRow(
                  Icons.people, "Max Occupants", _val('max_occupants')),
          ]),

          const SizedBox(height: 24),

          // Utilities & Inclusions
          const Text("Utilities & Inclusions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _inclusionChip('Water', _boolVal('with_water')),
              _inclusionChip('Electricity', _boolVal('with_electricity')),
              _inclusionChip('Internet', _boolVal('with_internet')),
              _inclusionChip('Parking', _boolVal('with_parking')),
            ],
          ),

          const SizedBox(height: 24),

          // Payment & Lease
          const Text("Payment & Lease",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _featureCard([
            if (_details?['security_deposit'] != null)
              _featureRow(Icons.attach_money, "Security Deposit",
                  _val('security_deposit')),
            if (_details?['advance_payment'] != null)
              _featureRow(Icons.payment, "Advance Payment",
                  _val('advance_payment')),
            if (_details?['lease_term'] != null)
              _featureRow(Icons.timer, "Lease Term", _val('lease_term')),
            if (_details?['payment_method'] != null)
              _featureRow(Icons.credit_card, "Payment Method",
                  _val('payment_method')),
            if (_details?['payment_terms'] != null)
              _featureRow(Icons.receipt_long, "Payment Terms",
                  _val('payment_terms')),
            if (_details?['association_dues'] != null)
              _featureRow(Icons.account_balance, "Association Dues",
                  _val('association_dues')),
            _featureRow(Icons.autorenew, "Renewable",
                _boolVal('renewable') ? 'Yes' : 'No'),
          ]),

          const SizedBox(height: 24),

          // Rental Rules
          const Text("Rental Rules",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _featureCard([
            _ruleRow(Icons.pets,
                _boolVal('pets_allowed') ? 'Pets allowed' : 'No pets allowed'),
            _ruleRow(
                Icons.smoking_rooms,
                _boolVal('smoking_allowed')
                    ? 'Smoking allowed'
                    : 'No smoking'),
            _ruleRow(
                Icons.nightlife,
                _boolVal('no_curfew')
                    ? 'No curfew'
                    : 'Has curfew'),
            _ruleRow(
                Icons.build,
                _boolVal('modification_allowed')
                    ? 'Modifications allowed'
                    : 'No modifications'),
            _ruleRow(
                Icons.swap_horiz,
                _boolVal('subletting_allowed')
                    ? 'Subletting allowed'
                    : 'No subletting'),
            if (_details?['guest_policy'] != null)
              _ruleRow(Icons.group, _val('guest_policy')),
          ]),

          const SizedBox(height: 24),

          // Hosted By
          const Text("Hosted By",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                _hostedByAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hostName(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _val('host_role', 'Property Owner'),
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (_details?['response_time'] != null)
                        Text(
                          'Responds ${_val('response_time')}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.grey[100],
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _openingChat ? null : _openChatWithLandlord,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _openingChat
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: VxrTokens.accent,
                                  ),
                                )
                              : const Icon(Icons.message_outlined,
                                  size: 20, color: VxrTokens.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: VxrTokens.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call,
                          size: 20, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- Amenities Tab ---
  Widget _buildAmenitiesTab() {
    // Combine DB amenities + inline booleans from listings table
    final inlineAmenities = <String, bool>{
      'Air Conditioning': _boolVal('has_aircon'),
      'Bed': _boolVal('has_bed'),
      'Cabinet': _boolVal('has_cabinet'),
      'Refrigerator': _boolVal('has_refrigerator'),
      'Stove': _boolVal('has_stove'),
      'Washing Machine': _boolVal('has_washing_machine'),
      'Water Heater': _boolVal('has_water_heater'),
      'Balcony': _boolVal('has_balcony'),
      'Storage': _boolVal('has_storage'),
      'Laundry Area': _boolVal('has_laundry_area'),
      'Natural Light': _boolVal('has_natural_light'),
      'Elevator': _boolVal('has_elevator'),
      'Pool': _boolVal('has_pool'),
      'Gym': _boolVal('has_gym'),
      'Playground': _boolVal('has_playground'),
      'Function Hall': _boolVal('has_function_hall'),
      'Security': _boolVal('has_security'),
      'Backup Power': _boolVal('has_backup_power'),
    };

    // Active inline amenities
    final activeInline = inlineAmenities.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Merge unique amenities
    final allAmenities = <String>{..._amenities, ...activeInline}.toList();

    // Parking info
    final hasParking = _boolVal('with_parking');
    final parkingType = _details?['parking_type']?.toString();
    final parkingFee = _details?['parking_fee'];

    // Appliances
    final otherAppliances = _details?['other_appliances']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allAmenities.isNotEmpty) ...[
            const Text("Amenities",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...allAmenities.map(
                (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAmenityItem(
                          _amenityIcon(a), a),
                    )),
          ],
          if (hasParking) ...[
            const SizedBox(height: 8),
            const Text("Parking",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _featureCard([
              if (parkingType != null)
                _featureRow(Icons.local_parking, "Type", parkingType),
              if (parkingFee != null)
                _featureRow(
                    Icons.attach_money, "Fee", parkingFee.toString()),
            ]),
          ],
          if (otherAppliances != null && otherAppliances.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("Other Appliances",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Text(otherAppliances,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ],
          if (allAmenities.isEmpty &&
              !hasParking &&
              (otherAppliances == null || otherAppliances.isEmpty))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.info_outline,
                        size: 50, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    Text('No amenities listed',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- Location Tab ---
  Widget _buildLocationTab() {
    final landmarks = _details?['nearby_landmarks']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Location",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Google Map
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(p.lat, p.lng),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('property'),
                    position: LatLng(p.lat, p.lng),
                    infoWindow: InfoWindow(title: p.title),
                  ),
                },
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                liteModeEnabled: true,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Full Address
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VxrTokens.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on,
                      color: VxrTokens.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Address",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _details?['full_address']?.toString() ??
                            p.location,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      if (_details?['postal_code'] != null)
                        Text(
                          'Postal Code: ${_val('postal_code')}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (landmarks != null && landmarks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("Nearby Landmarks",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Text(landmarks,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _circleButton({
    required IconData icon,
    Color color = Colors.white,
    required VoidCallback onPressed,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildListingTypeBadge() {
    final type = (_details?['listing_type']?.toString() ?? 'rent')
        .toLowerCase()
        .trim();
    final isLease = type == 'lease';
    final label = isLease ? 'For Lease' : 'For Rent';
    final bg = isLease
        ? const Color(0xff3b82f6).withOpacity(0.12)
        : VxrTokens.accent.withOpacity(0.12);
    final fg =
        isLease ? const Color(0xff1d4ed8) : VxrTokens.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VxrTokens.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: VxrTokens.accent, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _featureCard(List<Widget> rows) {
    final filtered = rows.whereType<Widget>().toList();
    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < filtered.length; i++) ...[
            filtered[i],
            if (i < filtered.length - 1) const Divider(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _ruleRow(IconData icon, String rule) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(rule,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _inclusionChip(String label, bool included) {
    return Chip(
      avatar: Icon(
        included ? Icons.check_circle : Icons.cancel,
        size: 18,
        color: included ? Colors.green : Colors.grey,
      ),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      backgroundColor: included ? Colors.green[50] : Colors.grey[100],
      side: BorderSide.none,
    );
  }

  Widget _buildAmenityItem(IconData icon, String amenity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VxrTokens.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: VxrTokens.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(amenity,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.check_circle, color: VxrTokens.accent),
        ],
      ),
    );
  }

  Widget _buildImage(String imageSource, double height) {
    final isUrl = imageSource.startsWith('http://') ||
        imageSource.startsWith('https://');

    if (isUrl) {
      return Image.network(
        imageSource,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(height),
      );
    }
    if (imageSource.isNotEmpty) {
      return Image.asset(
        imageSource,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(height),
      );
    }
    return _imagePlaceholder(height);
  }

  Widget _imagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment, size: 50, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text('No Photo',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _hostName() {
    final fromProfile =
        _landlord?['full_name']?.toString().trim() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    return _val('host_name', 'Property Host');
  }

  Widget _hostedByAvatar() {
    final url = (_landlord?['avatar_url'] ?? '').toString();
    final fallback = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: VxrTokens.accent.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(_hostName()),
        style: const TextStyle(
          color: VxrTokens.accent,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  IconData _amenityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('air') || lower.contains('aircon')) return Icons.ac_unit;
    if (lower.contains('wifi') || lower.contains('internet')) return Icons.wifi;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('pool') || lower.contains('swimming')) return Icons.pool;
    if (lower.contains('gym') || lower.contains('fitness')) return Icons.fitness_center;
    if (lower.contains('elevator') || lower.contains('lift')) return Icons.elevator;
    if (lower.contains('security') || lower.contains('guard')) return Icons.security;
    if (lower.contains('laundry') || lower.contains('washing')) return Icons.local_laundry_service;
    if (lower.contains('balcony')) return Icons.balcony;
    if (lower.contains('storage')) return Icons.warehouse;
    if (lower.contains('bed')) return Icons.bed;
    if (lower.contains('cabinet') || lower.contains('closet')) return Icons.door_sliding;
    if (lower.contains('refrigerator') || lower.contains('fridge')) return Icons.kitchen;
    if (lower.contains('stove') || lower.contains('cooking')) return Icons.microwave;
    if (lower.contains('water heater')) return Icons.hot_tub;
    if (lower.contains('light') || lower.contains('natural')) return Icons.wb_sunny;
    if (lower.contains('playground')) return Icons.child_care;
    if (lower.contains('function') || lower.contains('hall')) return Icons.meeting_room;
    if (lower.contains('power') || lower.contains('generator')) return Icons.bolt;
    if (lower.contains('furnish')) return Icons.chair;
    if (lower.contains('pet')) return Icons.pets;
    return Icons.check_circle_outline;
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: VxrTokens.bg, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Zoomable images
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: _buildFullImage(widget.images[index]),
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
                decoration: BoxDecoration(
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
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.images.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentIndex == index ? 10 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullImage(String imageSource) {
    final isUrl =
        imageSource.startsWith('http://') || imageSource.startsWith('https://');

    if (isUrl) {
      return Image.network(
        imageSource,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    if (imageSource.isNotEmpty) {
      return Image.asset(
        imageSource,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image, size: 60, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text('Image not available',
            style: TextStyle(color: Colors.grey[500])),
      ],
    );
  }
}
