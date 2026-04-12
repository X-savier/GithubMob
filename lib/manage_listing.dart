import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
const kCoral = Color(0xFFE8735A);
const kRedSelected = Color(0xFFC0392B);
const kPageBg = Color(0xFFF0F2F5);
const kBorderColor = Color(0xFFDEDEDE);
const kHintColor = Color(0xFFAAAAAA);
const kLabelColor = Color(0xFF333333);
const kSectionTitle = Color(0xFF1A1A1A);

// ─────────────────────────────────────────────
// LISTING DATA MODEL
// ─────────────────────────────────────────────
class ListingData {
  String title;
  String location;
  String price;
  String beds;
  String baths;
  String sqm;
  XFile? coverPhoto;
  List<XFile> propertyImages;

  ListingData({
    required this.title,
    required this.location,
    required this.price,
    required this.beds,
    required this.baths,
    required this.sqm,
    this.coverPhoto,
    this.propertyImages = const [],
  });
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
  final List<ListingData> _listings = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        backgroundColor: kCoral,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _listings.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemCount: _listings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildListingCard(_listings[index], index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
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
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4),
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
          onPressed: () {
            Navigator.pop(ctx);
            setState(() => _listings.removeAt(index));
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
    final result = await Navigator.push<ListingData>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListingScreen(existingListing: _listings[index]),
      ),
    );
    if (result != null) setState(() => _listings[index] = result);
  }

  Widget _buildCardImage(ListingData listing) {
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
    return Container(
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
  }

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
    final result = await Navigator.push<ListingData>(
      context,
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (result != null) setState(() => _listings.add(result));
  }
}

// ─────────────────────────────────────────────
// CREATE LISTING SCREEN
// ─────────────────────────────────────────────
class CreateListingScreen extends StatefulWidget {
  final ListingData? existingListing;
  const CreateListingScreen({super.key, this.existingListing});

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
  final _addressSearchCtrl = TextEditingController();
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
      _hostRole;
  bool _isImmediate = true;
  DateTime? _availableFrom;
  String _leaseTerm = '12 months';

  final Map<String, bool> _amenities = {
    'No Smoking': false,
    'Parking': false,
    'Seating Spot': false,
    'Air Conditioning': false,
    'Kitchen': false,
    'CCTV': false,
    'WiFi/Link': false,
    'Swimming Pool': false,
    'Balcony': false,
    'Water Tank': false,
  };

  bool _petsAllowed = false, _smokingAllowed = false, _noCurfew = true;
  String _guestPolicy = 'Day/Nite Only', _responseTime = 'Within 1 Hour';

  final ImagePicker _picker = ImagePicker();
  List<XFile> _propertyImages = [], _media360Images = [];
  XFile? _coverPhoto;

  @override
  void initState() {
    super.initState();
    final e = widget.existingListing;
    if (e != null) {
      _listingTitleCtrl.text = e.title;
      _monthlyRentCtrl.text = e.price;
      _coverPhoto = e.coverPhoto;
      _propertyImages = List.from(e.propertyImages);
      final parts = e.location.split(', ');
      if (parts.length >= 2) {
        _cityCtrl.text = parts[0];
        _provinceCtrl.text = parts[1];
      }
      _squareMeterCtrl.text = e.sqm;
      _bedrooms = e.beds == 'Studio' ? 'Studio' : e.beds;
      _bathrooms = e.baths;
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
      _addressSearchCtrl,
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
        backgroundColor: kCoral,
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
                widget.existingListing != null
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
            _buildListingTitleSection(),
            _buildLocationDetailsSection(),
            _buildPropertyDetailsSection(),
            _buildRentalPricingSection(),
            _buildAvailabilityLeaseSection(),
            _buildUnitDescriptionSection(),
            _buildAmenitiesSection(),
            _buildRulesAndPoliciesSection(),
            _buildHostInformationSection(),
            _buildMediaUploadSection(),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorderColor.withOpacity(0.5)),
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
    value: value,
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

  Widget _buildLocationDetailsSection() => _sectionCard(
    title: 'Location Details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTwoColumnRow(
          child1: _buildTextFieldColumn('City', _cityCtrl, 'Enter city'),
          child2: _buildTextFieldColumn(
            'Province / Region',
            _provinceCtrl,
            'Enter province or region',
          ),
        ),
        const SizedBox(height: 12),
        _fieldLabel('Full Address'),
        TextField(
          controller: _fullAddressCtrl,
          decoration: _inputDecoration('Enter full Address'),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnRow(
          child1: _buildTextFieldColumn(
            'Street Area',
            _streetAreaCtrl,
            'Enter street area',
          ),
          child2: _buildTextFieldColumn(
            'Postal Code',
            _postalCodeCtrl,
            'Enter postal code',
          ),
        ),
        const SizedBox(height: 12),
        _fieldLabel('Search for your property address'),
        TextField(
          controller: _addressSearchCtrl,
          decoration:
              _inputDecoration(
                'Start typing your address in the Philippines',
              ).copyWith(
                prefixIcon: const Icon(
                  Icons.search,
                  color: kHintColor,
                  size: 18,
                ),
              ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        _fieldLabel('Map:'),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kBorderColor),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 32,
                color: Color(0xFF999999),
              ),
              SizedBox(height: 6),
              Text(
                'Map Preview',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ],
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
        _fieldLabel('Payment Terms:'),
        _dropdown(
          hint: 'Select payment terms',
          value: _paymentTerms,
          items: ['Monthly', 'Quarterly', 'Semi-Annual', 'Annual'],
          onChanged: (v) => setState(() => _paymentTerms = v),
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
        SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? 200
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
                onChanged: (v) => setState(() => _leaseTerm = v ?? '12 months'),
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

  Widget _buildRulesAndPoliciesSection() => _sectionCard(
    title: 'Rental Rules & Policies',
    child: Column(
      children: [
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
                        onChanged: (_) => setState(() => _petsAllowed = false),
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
      ],
    ),
  );

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
                items: ['Owner', 'Agent', 'Caretaker', 'Property Manager'],
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

  Widget _buildMediaUploadSection() => _sectionCard(
    title: 'Media Upload',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Images and media for your listing',
          style: TextStyle(fontSize: 12, color: kHintColor),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 20,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width > 600
                  ? (MediaQuery.of(context).size.width - 80) / 3
                  : double.infinity,
              child: _multiImageUploadBox(
                icon: Icons.image_outlined,
                label: 'Property Images',
                subLabel: 'Click to upload',
                images: _propertyImages,
                onTap: () => _pickMultipleImages('property'),
                onRemove: (i) => _removeImage('property', i),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width > 600
                  ? (MediaQuery.of(context).size.width - 80) / 3
                  : double.infinity,
              child: _multiImageUploadBox(
                icon: Icons.camera_alt_outlined,
                label: '360 Media',
                subLabel: 'Click to upload',
                images: _media360Images,
                onTap: () => _pickMultipleImages('360'),
                onRemove: (i) => _removeImage('360', i),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width > 600
                  ? (MediaQuery.of(context).size.width - 80) / 3
                  : double.infinity,
              child: _coverPhotoUploadBox(),
            ),
          ],
        ),
      ],
    ),
  );

  // Helper Methods for Image Upload
  Future<void> _pickMultipleImages(String type) async {
    final List<XFile> picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        if (type == 'property') {
          _propertyImages.addAll(picked);
        } else {
          _media360Images.addAll(picked);
        }
      });
    }
  }

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
      _media360Images.removeAt(index);
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

  Widget _multiImageUploadBox({
    required IconData icon,
    required String label,
    required String subLabel,
    required List<XFile> images,
    required VoidCallback onTap,
    required ValueChanged<int> onRemove,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: onTap,
        child: DashedBorderBox(
          child: Container(
            height: 100,
            width: double.infinity,
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: const Color(0xFF999999)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kLabelColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: const TextStyle(fontSize: 11, color: kHintColor),
                ),
              ],
            ),
          ),
        ),
      ),
      if (images.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: images.asMap().entries.map((entry) {
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: XFileImage(
                    file: entry.value,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onRemove(entry.key),
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
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          '${images.length} file(s) selected',
          style: const TextStyle(fontSize: 11, color: kHintColor),
        ),
      ],
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            side: const BorderSide(color: kBorderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            backgroundColor: Colors.white,
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: kLabelColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            final listing = ListingData(
              title: _listingTitleCtrl.text.isEmpty
                  ? 'Modern Studio Apartment'
                  : _listingTitleCtrl.text,
              location: _cityCtrl.text.isEmpty
                  ? 'Makati City, Metro Manila'
                  : '${_cityCtrl.text}, ${_provinceCtrl.text}',
              price:
                  _monthlyRentCtrl.text.isEmpty ||
                      _monthlyRentCtrl.text == '0.00'
                  ? '4,500'
                  : _monthlyRentCtrl.text,
              beds: _bedrooms ?? '1',
              baths: _bathrooms ?? '1',
              sqm: _squareMeterCtrl.text.isEmpty ? '25' : _squareMeterCtrl.text,
              coverPhoto: _coverPhoto,
              propertyImages: _propertyImages,
            );
            Navigator.pop(context, listing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kCoral,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
          child: Text(
            widget.existingListing != null ? 'Save Changes' : 'Create Listing',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
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
