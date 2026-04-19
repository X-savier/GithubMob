import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Property {
  final String? id;
  final String image;
  final String title;
  final String location;
  final String city;
  final String barangay;
  final String price;
  final int beds;
  final String baths;
  final String area;
  final String? label;
  final double lat;
  final double lng;
  final String? propertyType;
  final String? description;
  final String? furnishing;
  final bool petsAllowed;
  final bool smokingAllowed;
  final String? landlordId;
  double? distanceKm;

  Property({
    this.id,
    required this.image,
    required this.title,
    required this.location,
    this.city = '',
    this.barangay = '',
    required this.price,
    required this.beds,
    required this.baths,
    required this.area,
    required this.lat,
    required this.lng,
    this.label,
    this.propertyType,
    this.description,
    this.furnishing,
    this.petsAllowed = false,
    this.smokingAllowed = false,
    this.landlordId,
    this.distanceKm,
  });

  factory Property.fromMap(Map<String, dynamic> map) {
    final cityVal = map['city']?.toString() ?? '';
    final barangayVal = map['barangay']?.toString() ?? '';

    // Build a readable location string
    final parts = <String>[
      if (barangayVal.isNotEmpty) barangayVal,
      if (cityVal.isNotEmpty) cityVal,
    ];
    final location = parts.isNotEmpty
        ? parts.join(', ')
        : (map['full_address']?.toString() ?? '');

    // Format rent as ₱X,XXX/month
    final rent = (map['monthly_rent'] as num?)?.toDouble() ?? 0;
    final formatted = '₱${_formatNumber(rent)}/month';

    // Parse bedrooms text → int (e.g. "2" → 2, "Studio" → 0)
    final bedsRaw = map['bedrooms']?.toString() ?? '0';
    final bedsInt = int.tryParse(bedsRaw) ?? 0;

    // Parse square_meters → "Xm²"
    final sqm = (map['square_meters'] as num?)?.toDouble();
    final areaStr = sqm != null ? '${sqm.toStringAsFixed(0)}m²' : '';

    // Build full image URL from Supabase Storage path
    final rawPath = map['cover_photo_url']?.toString() ?? '';
    final imageUrl = buildStorageUrl(rawPath);

    return Property(
      id: map['id']?.toString(),
      image: imageUrl,
      title: map['title'] ?? '',
      location: location,
      price: formatted,
      beds: bedsInt,
      baths: (map['bathrooms'] ?? '1').toString(),
      area: areaStr,
      lat: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      lng: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      label: map['property_type'],
      propertyType: map['property_type'],
      description: map['description'],
      furnishing: map['furnishing'],
      petsAllowed: map['pets_allowed'] == true,
      smokingAllowed: map['smoking_allowed'] == true,
      landlordId: map['landlord_id']?.toString(),
      city: cityVal,
      barangay: barangayVal,
    );
  }
}

/// Convert a Supabase Storage path to a full public URL
String buildStorageUrl(String path) {
  if (path.isEmpty) return '';
  // Already a full URL
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  // Use Supabase SDK to get the public URL
  return Supabase.instance.client.storage
      .from('listing-images')
      .getPublicUrl(path);
}

/// Format number with commas (e.g. 12000 → "12,000")
String _formatNumber(double n) {
  final str = n.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

/// Haversine distance in km (no external API needed)
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _deg2rad(double deg) => deg * (pi / 180);

/// Ask for location permission and return current position (or null)
Future<Position?> getUserLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  } catch (_) {
    return null;
  }
}

/// Compute distance for every property in the list
void computeDistances(List<Property> properties, double userLat, double userLng) {
  for (final p in properties) {
    p.distanceKm = haversineKm(userLat, userLng, p.lat, p.lng);
  }
}

/// In-memory cache of properties fetched from Supabase
List<Property> allProperties = [];

/// Fetch active listings from the Supabase 'listings_full' view
Future<List<Property>> fetchProperties() async {
  try {
    final data = await Supabase.instance.client
        .from('listings_full')
        .select()
        .eq('status', 'active')
        .order('created_at', ascending: false);

    allProperties = (data as List)
        .map((row) => Property.fromMap(row as Map<String, dynamic>))
        .toList();
    debugPrint('fetchProperties: loaded ${allProperties.length} listings');
    return allProperties;
  } catch (e) {
    debugPrint('fetchProperties ERROR: $e');
    return allProperties;
  }
}

/// Fetch full listing details (all columns) via the listings_full view
Future<Map<String, dynamic>?> fetchListingDetails(String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('listings_full')
        .select()
        .eq('id', listingId)
        .maybeSingle();
    return data;
  } catch (e) {
    debugPrint('fetchListingDetails ERROR: $e');
    return null;
  }
}

/// Fetch images for a listing from listing_images table
Future<List<String>> fetchListingImages(String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('listing_images')
        .select('image_url, sort_order, image_type')
        .eq('listing_id', listingId)
        .order('sort_order', ascending: true);

    return (data as List)
        .where((row) => (row['image_type'] ?? 'normal') == 'normal')
        .map((row) {
      final raw = row['image_url']?.toString() ?? '';
      return buildStorageUrl(raw);
    }).where((u) => u.isNotEmpty).toList();
  } catch (e) {
    debugPrint('fetchListingImages ERROR: $e');
    return [];
  }
}

/// Fetch amenities for a listing via the listing_amenity join table
Future<List<String>> fetchListingAmenities(String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('listing_amenity')
        .select('amenity:amenity_id(name)')
        .eq('listing_id', listingId);

    return (data as List).map((row) {
      final amenity = row['amenity'];
      if (amenity is Map) return amenity['name']?.toString() ?? '';
      return '';
    }).where((n) => n.isNotEmpty).toList();
  } catch (e) {
    debugPrint('fetchListingAmenities ERROR: $e');
    return [];
  }
}

/// Filter by bedroom category: 0=All, 1=Studio(0 beds), 2=1BR, 3=2BR, 4=3+BR
List<Property> propertiesByCategory(int category, {List<Property>? source}) {
  final list = source ?? allProperties;
  switch (category) {
    case 1:
      return list.where((p) => p.beds == 1).toList();
    case 2:
      return list.where((p) => p.beds == 2).toList();
    case 3:
      return list.where((p) => p.beds >= 3).toList();
    default:
      return List.of(list);
  }
}

/// Determine the user's city from the nearest property
String detectUserCity(List<Property> properties) {
  if (properties.isEmpty) return '';
  final sorted = List<Property>.from(properties)
    ..sort((a, b) {
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });
  return sorted.first.city;
}

/// Get properties in a specific city
List<Property> propertiesInCity(String city) {
  if (city.isEmpty) return List.of(allProperties);
  return allProperties
      .where((p) => p.city.toLowerCase() == city.toLowerCase())
      .toList();
}

/// Get nearest properties sorted by distance
List<Property> nearestProperties() {
  final sorted = List<Property>.from(allProperties)
    ..sort((a, b) {
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });
  return sorted;
}

bool passesFilters(Property property, Map<String, dynamic> filters) {
  if (filters.isEmpty) return true;

  if (filters.containsKey('bedrooms') && filters['bedrooms'] > 0) {
    if (property.beds != filters['bedrooms']) return false;
  }

  if (filters.containsKey('bathrooms') && filters['bathrooms'] > 0) {
    int propBaths = int.tryParse(property.baths) ?? 0;
    if (propBaths != filters['bathrooms']) return false;
  }

  if (filters.containsKey('minArea') && filters.containsKey('maxArea')) {
    int propArea = int.tryParse(property.area.replaceAll('m²', '')) ?? 0;
    if (propArea < filters['minArea'] || propArea > filters['maxArea']) {
      return false;
    }
  }

  final propertyType = filters['propertyType'];
  if (propertyType != null && propertyType != 'Any') {
    if (property.propertyType != propertyType) return false;
  }

  final furnishing = filters['furnishing'];
  if (furnishing != null && furnishing != 'Any') {
    if (property.furnishing != furnishing) return false;
  }

  final petPolicy = filters['petPolicy'];
  if (petPolicy != null && petPolicy != 'Any') {
    if (petPolicy == 'Pets Allowed' && !property.petsAllowed) return false;
    if (petPolicy == 'No Pets' && property.petsAllowed) return false;
  }

  final smokingPolicy = filters['smokingPolicy'];
  if (smokingPolicy != null && smokingPolicy != 'Any') {
    if (smokingPolicy == 'Smoking Allowed' && !property.smokingAllowed) return false;
    if (smokingPolicy == 'No Smoking' && property.smokingAllowed) return false;
  }

  return true;
}

/// Sort properties based on filter selection
void sortProperties(List<Property> properties, String sortBy) {
  switch (sortBy) {
    case 'Price: Low to High':
      properties.sort((a, b) {
        final aPrice = double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final bPrice = double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        return aPrice.compareTo(bPrice);
      });
      break;
    case 'Price: High to Low':
      properties.sort((a, b) {
        final aPrice = double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final bPrice = double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        return bPrice.compareTo(aPrice);
      });
      break;
    case 'Nearest':
      properties.sort((a, b) {
        final aDist = a.distanceKm ?? double.infinity;
        final bDist = b.distanceKm ?? double.infinity;
        return aDist.compareTo(bDist);
      });
      break;
  }
}

// ─────────────────────────────────────────────
// NORMALIZED LISTINGS CRUD
// ─────────────────────────────────────────────

/// Check if the current user has any listings
Future<bool> hasUserListings() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await Supabase.instance.client
        .from('listings')
        .select('id')
        .eq('landlord_id', userId)
        .limit(1);
    return (data as List).isNotEmpty;
  } catch (e) {
    debugPrint('hasUserListings ERROR: $e');
    return false;
  }
}

/// Fetch listings belonging to the current landlord
Future<List<Property>> fetchLandlordListings() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('listings_full')
        .select()
        .eq('landlord_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => Property.fromMap(row as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('fetchLandlordListings ERROR: $e');
    return [];
  }
}

/// Insert a new listing across all normalized tables.
/// Returns the listing ID on success.
Future<String?> insertListing({
  required Map<String, dynamic> core,
  required Map<String, dynamic> location,
  required Map<String, dynamic> details,
  required Map<String, dynamic> amenities,
  required Map<String, dynamic> utilities,
  required Map<String, dynamic> buildingFeatures,
  required Map<String, dynamic> financials,
  required Map<String, dynamic> availability,
  required Map<String, dynamic> policies,
  required Map<String, dynamic> requirements,
  required Map<String, dynamic> hostInfo,
}) async {
  try {
    final client = Supabase.instance.client;
    final result = await client
        .from('listings')
        .insert(core)
        .select('id')
        .single();
    final listingId = result['id'] as String;

    await Future.wait([
      client.from('listing_locations').insert({...location, 'listing_id': listingId}),
      client.from('listing_details').insert({...details, 'listing_id': listingId}),
      client.from('listing_amenities').insert({...amenities, 'listing_id': listingId}),
      client.from('listing_utilities').insert({...utilities, 'listing_id': listingId}),
      client.from('listing_building_features').insert({...buildingFeatures, 'listing_id': listingId}),
      client.from('listing_financials').insert({...financials, 'listing_id': listingId}),
      client.from('listing_availability').insert({...availability, 'listing_id': listingId}),
      client.from('listing_policies').insert({...policies, 'listing_id': listingId}),
      client.from('listing_requirements').insert({...requirements, 'listing_id': listingId}),
      client.from('listing_host_info').insert({...hostInfo, 'listing_id': listingId}),
    ]);

    return listingId;
  } catch (e) {
    debugPrint('insertListing ERROR: $e');
    return null;
  }
}

/// Update an existing listing across all normalized tables
Future<bool> updateListing({
  required String listingId,
  required Map<String, dynamic> core,
  required Map<String, dynamic> location,
  required Map<String, dynamic> details,
  required Map<String, dynamic> amenities,
  required Map<String, dynamic> utilities,
  required Map<String, dynamic> buildingFeatures,
  required Map<String, dynamic> financials,
  required Map<String, dynamic> availability,
  required Map<String, dynamic> policies,
  required Map<String, dynamic> requirements,
  required Map<String, dynamic> hostInfo,
}) async {
  try {
    final client = Supabase.instance.client;
    await Future.wait([
      client.from('listings').update(core).eq('id', listingId),
      client.from('listing_locations').update(location).eq('listing_id', listingId),
      client.from('listing_details').update(details).eq('listing_id', listingId),
      client.from('listing_amenities').update(amenities).eq('listing_id', listingId),
      client.from('listing_utilities').update(utilities).eq('listing_id', listingId),
      client.from('listing_building_features').update(buildingFeatures).eq('listing_id', listingId),
      client.from('listing_financials').update(financials).eq('listing_id', listingId),
      client.from('listing_availability').update(availability).eq('listing_id', listingId),
      client.from('listing_policies').update(policies).eq('listing_id', listingId),
      client.from('listing_requirements').update(requirements).eq('listing_id', listingId),
      client.from('listing_host_info').update(hostInfo).eq('listing_id', listingId),
    ]);
    return true;
  } catch (e) {
    debugPrint('updateListing ERROR: $e');
    return false;
  }
}

/// Delete a listing by ID (cascade handles child tables)
Future<bool> deleteListingFromSupabase(String listingId) async {
  try {
    await Supabase.instance.client
        .from('listings')
        .delete()
        .eq('id', listingId);
    return true;
  } catch (e) {
    debugPrint('deleteListingFromSupabase ERROR: $e');
    return false;
  }
}

/// Save listing images to listing_images table
Future<void> saveListingImages(
  String listingId,
  List<String> storagePaths, {
  String imageType = 'normal',
  String uploadSource = 'upload',
}) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final rows = storagePaths.asMap().entries.map((e) => {
      'listing_id': listingId,
      'image_url': e.value,
      'image_type': imageType,
      'upload_source': uploadSource,
      'sort_order': e.key,
      'is_cover': e.key == 0,
      'uploaded_by': userId,
    }).toList();
    if (rows.isNotEmpty) {
      await Supabase.instance.client.from('listing_images').insert(rows);
    }
  } catch (e) {
    debugPrint('saveListingImages ERROR: $e');
  }
}

/// Delete a listing image by its ID
Future<bool> deleteListingImage(String imageId) async {
  try {
    await Supabase.instance.client
        .from('listing_images')
        .delete()
        .eq('id', imageId);
    return true;
  } catch (e) {
    debugPrint('deleteListingImage ERROR: $e');
    return false;
  }
}

/// Fetch all image records (with metadata) for a listing
Future<List<Map<String, dynamic>>> fetchListingImageRecords(String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('listing_images')
        .select()
        .eq('listing_id', listingId)
        .order('sort_order', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchListingImageRecords ERROR: $e');
    return [];
  }
}

/// Save a panorama image record with room label
Future<void> savePanoramaImage({
  required String listingId,
  required String storagePath,
  required String roomLabel,
  String uploadSource = 'capture',
  int sortOrder = 0,
}) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    await Supabase.instance.client.from('listing_images').insert({
      'listing_id': listingId,
      'image_url': storagePath,
      'image_type': 'panorama',
      'upload_source': uploadSource,
      'room_label': roomLabel,
      'sort_order': sortOrder,
      'is_cover': false,
      'uploaded_by': userId,
    });
  } catch (e) {
    debugPrint('savePanoramaImage ERROR: $e');
  }
}

/// Fetch all panorama image records for a listing (with room_label)
Future<List<Map<String, dynamic>>> fetchPanoramaImages(String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('listing_images')
        .select()
        .eq('listing_id', listingId)
        .eq('image_type', 'panorama')
        .order('sort_order', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchPanoramaImages ERROR: $e');
    return [];
  }
}

// ─────────────────────────────────────────────
// RENTAL APPLICATIONS
// ─────────────────────────────────────────────

/// Submit a rental application (tenant side).
/// Returns the application ID on success.
Future<String?> submitRentalApplication(Map<String, dynamic> data) async {
  try {
    final result = await Supabase.instance.client
        .from('application')
        .insert(data)
        .select('id')
        .single();
    return result['id'] as String;
  } catch (e) {
    debugPrint('submitRentalApplication ERROR: $e');
    return null;
  }
}

/// Save uploaded document paths for an application
Future<void> saveApplicationDocuments(
    String applicationId, List<Map<String, String>> docs) async {
  try {
    final rows = docs.map((d) => {
      'application_id': applicationId,
      ...d,
    }).toList();
    if (rows.isNotEmpty) {
      await Supabase.instance.client
          .from('application_document')
          .insert(rows);
      debugPrint('saveApplicationDocuments: inserted ${rows.length} rows');
    }
  } catch (e) {
    debugPrint('saveApplicationDocuments ERROR: $e');
    rethrow;
  }
}

/// Fetch applications for a specific listing (landlord side)
Future<List<Map<String, dynamic>>> fetchApplicationsForListing(
    String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('application')
        .select()
        .eq('listing_id', listingId)
        .order('submitted_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchApplicationsForListing ERROR: $e');
    return [];
  }
}

/// Fetch a single application's full details
Future<Map<String, dynamic>?> fetchApplicationDetails(
    String applicationId) async {
  try {
    final data = await Supabase.instance.client
        .from('application')
        .select()
        .eq('id', applicationId)
        .maybeSingle();
    return data;
  } catch (e) {
    debugPrint('fetchApplicationDetails ERROR: $e');
    return null;
  }
}

/// Fetch documents uploaded for an application
Future<List<Map<String, dynamic>>> fetchApplicationDocuments(
    String applicationId) async {
  try {
    final data = await Supabase.instance.client
        .from('application_document')
        .select()
        .eq('application_id', applicationId)
        .order('uploaded_at', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchApplicationDocuments ERROR: $e');
    return [];
  }
}

/// Update application status (approve / reject)
Future<bool> updateApplicationStatus(
    String applicationId, String status) async {
  try {
    await Supabase.instance.client
        .from('application')
        .update({
          'status': status,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', applicationId);
    return true;
  } catch (e) {
    debugPrint('updateApplicationStatus ERROR: $e');
    return false;
  }
}

/// Count applications per listing (for landlord units overview)
Future<Map<String, int>> fetchApplicationCounts(
    List<String> listingIds) async {
  try {
    final counts = <String, int>{};
    for (final id in listingIds) {
      final data = await Supabase.instance.client
          .from('application')
          .select('id')
          .eq('listing_id', id)
          .eq('status', 'pending');
      counts[id] = (data as List).length;
    }
    return counts;
  } catch (e) {
    debugPrint('fetchApplicationCounts ERROR: $e');
    return {};
  }
}

/// Fetch applications submitted by the current tenant
Future<List<Map<String, dynamic>>> fetchMyApplications() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('application')
        .select('*, listings_full(*)')
        .eq('tenant_id', userId)
        .order('submitted_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchMyApplications ERROR: $e');
    return [];
  }
}

/// Check if tenant already applied to a listing
Future<bool> hasAppliedToListing(String listingId) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await Supabase.instance.client
        .from('application')
        .select('id')
        .eq('listing_id', listingId)
        .eq('tenant_id', userId)
        .maybeSingle();
    return data != null;
  } catch (e) {
    debugPrint('hasAppliedToListing ERROR: $e');
    return false;
  }
}
