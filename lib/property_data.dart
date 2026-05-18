import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
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
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
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
void computeDistances(
  List<Property> properties,
  double userLat,
  double userLng,
) {
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

/// Fetch images for a listing from listing_images table.
/// Falls back to listing the storage bucket folder directly when the table
/// returns no rows (table missing, RLS issue, or images not yet recorded).
Future<List<String>> fetchListingImages(String listingId) async {
  try {
    final data = await Supabase.instance.client
        .from('listing_image')
        .select()
        .eq('listing_id', listingId);

    final rows = (data as List).cast<Map<String, dynamic>>();

    // Exclude panorama-typed rows; include anything else (null, 'normal', etc.)
    final filtered =
        rows.where((r) {
          final t = r['type']?.toString() ?? '';
          return t != 'panorama';
        }).toList()..sort((a, b) {
          final ao = (a['sort_order'] as num?)?.toInt() ?? 0;
          final bo = (b['sort_order'] as num?)?.toInt() ?? 0;
          return ao.compareTo(bo);
        });

    final urls = filtered
        .map((r) {
          final raw = (r['url'] ?? '').toString();
          return buildStorageUrl(raw);
        })
        .where((u) => u.isNotEmpty)
        .toList();

    if (urls.isNotEmpty) return urls;

    // ── Storage fallback ──────────────────────────────────────────
    // The listing_image table returned nothing (table may not exist yet,
    // RLS may block reads, or images were uploaded before records were
    // written). List the listing's folder in the storage bucket directly
    // so images still display on mobile and web.
    return await _fetchImagesFromStorage(listingId);
  } catch (e) {
    debugPrint('fetchListingImages ERROR: $e');
    // Even when the table query throws, attempt the storage fallback.
    return await _fetchImagesFromStorage(listingId);
  }
}

/// List property images for [listingId] directly from the
/// `listing-images` storage bucket (fallback when the DB table fails).
/// Only includes files whose names start with `img_` to exclude the
/// cover photo (`cover_*`) and panoramas (`pano_*`).
Future<List<String>> _fetchImagesFromStorage(String listingId) async {
  try {
    final objects = await Supabase.instance.client.storage
        .from('listing-images')
        .list(path: listingId);
    return objects
        .where((o) => o.name.startsWith('img_'))
        .map((o) => buildStorageUrl('$listingId/${o.name}'))
        .where((u) => u.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('_fetchImagesFromStorage ERROR: $e');
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

    return (data as List)
        .map((row) {
          final amenity = row['amenity'];
          if (amenity is Map) return amenity['name']?.toString() ?? '';
          return '';
        })
        .where((n) => n.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('fetchListingAmenities ERROR: $e');
    return [];
  }
}

/// Filter by bedroom category: 0=All, 1=1BR, 2=2BR, 3=3+BR
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

/// Up to [count] cities (other than [excludeCity]) ranked by the
/// closest property in each. Cities with no properties or no city
/// label are skipped. Requires [computeDistances] to have been run.
List<String> nearbyCities({String excludeCity = '', int count = 2}) {
  final byCity = <String, double>{};
  for (final p in allProperties) {
    if (p.city.isEmpty) continue;
    if (excludeCity.isNotEmpty &&
        p.city.toLowerCase() == excludeCity.toLowerCase()) {
      continue;
    }
    final d = p.distanceKm ?? double.infinity;
    final existing = byCity[p.city];
    if (existing == null || d < existing) {
      byCity[p.city] = d;
    }
  }
  final sorted = byCity.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return sorted.take(count).map((e) => e.key).toList();
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
    if (smokingPolicy == 'Smoking Allowed' && !property.smokingAllowed)
      return false;
    if (smokingPolicy == 'No Smoking' && property.smokingAllowed) return false;
  }

  return true;
}

/// Sort properties based on filter selection
void sortProperties(List<Property> properties, String sortBy) {
  switch (sortBy) {
    case 'Price: Low to High':
      properties.sort((a, b) {
        final aPrice =
            double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final bPrice =
            double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        return aPrice.compareTo(bPrice);
      });
      break;
    case 'Price: High to Low':
      properties.sort((a, b) {
        final aPrice =
            double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final bPrice =
            double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
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
// BOOKMARKS / FAVORITES
// ─────────────────────────────────────────────

/// Add a bookmark for the current user on [listingId]. No-op if
/// already bookmarked thanks to the (user_id, listing_id) unique
/// constraint + onConflict.
Future<bool> addBookmark(String listingId) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    await Supabase.instance.client.from('bookmark').upsert({
      'user_id': userId,
      'listing_id': listingId,
    }, onConflict: 'user_id,listing_id');
    return true;
  } catch (e) {
    debugPrint('addBookmark ERROR: $e');
    return false;
  }
}

/// Remove the current user's bookmark for [listingId]. Idempotent.
Future<bool> removeBookmark(String listingId) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    await Supabase.instance.client
        .from('bookmark')
        .delete()
        .eq('user_id', userId)
        .eq('listing_id', listingId);
    return true;
  } catch (e) {
    debugPrint('removeBookmark ERROR: $e');
    return false;
  }
}

/// All listing IDs the current user has bookmarked. Returned as a
/// set so callers can do O(1) membership checks per card.
Future<Set<String>> fetchMyBookmarkedListingIds() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return {};
    final data = await Supabase.instance.client
        .from('bookmark')
        .select('listing_id')
        .eq('user_id', userId);
    return (data as List).map((r) => r['listing_id'].toString()).toSet();
  } catch (e) {
    debugPrint('fetchMyBookmarkedListingIds ERROR: $e');
    return {};
  }
}

/// Hydrate the current user's bookmarked properties via the
/// `listings_full` view. Drives the Favorites screen.
Future<List<Property>> fetchMyBookmarks() async {
  try {
    final ids = await fetchMyBookmarkedListingIds();
    if (ids.isEmpty) return [];
    final data = await Supabase.instance.client
        .from('listings_full')
        .select()
        .inFilter('id', ids.toList());
    return (data as List)
        .map((row) => Property.fromMap(row as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('fetchMyBookmarks ERROR: $e');
    return [];
  }
}

// ─────────────────────────────────────────────
// VERIFICATION
// ─────────────────────────────────────────────

/// One Philippine valid ID supported by the AI verification flow.
class PhilippineIdType {
  final String key; // matches verifications.id_type
  final String displayName;
  final bool requiresBack;
  final IconData icon;
  const PhilippineIdType({
    required this.key,
    required this.displayName,
    required this.requiresBack,
    required this.icon,
  });
}

/// All ID types the verify-identity Edge Function knows how to OCR.
/// Order = display order in the picker grid. Keep in sync with
/// `ID_SCHEMAS` / `ID_LABELS` in
/// `supabase/functions/verify-identity/index.ts`.
const List<PhilippineIdType> kPhilippineIdTypes = [
  PhilippineIdType(
    key: 'philsys',
    displayName: 'PhilSys (National ID)',
    requiresBack: true,
    icon: Icons.badge_outlined,
  ),
  PhilippineIdType(
    key: 'umid',
    displayName: 'UMID',
    requiresBack: false,
    icon: Icons.account_box_outlined,
  ),
  PhilippineIdType(
    key: 'drivers_license',
    displayName: "Driver's License",
    requiresBack: true,
    icon: Icons.directions_car_outlined,
  ),
  PhilippineIdType(
    key: 'passport',
    displayName: 'Philippine Passport',
    requiresBack: false,
    icon: Icons.flight_takeoff_outlined,
  ),
  PhilippineIdType(
    key: 'postal_id',
    displayName: 'Postal ID',
    requiresBack: false,
    icon: Icons.local_post_office_outlined,
  ),
  PhilippineIdType(
    key: 'sss',
    displayName: 'SSS ID',
    requiresBack: false,
    icon: Icons.assignment_ind_outlined,
  ),
  PhilippineIdType(
    key: 'prc',
    displayName: 'PRC ID',
    requiresBack: false,
    icon: Icons.school_outlined,
  ),
  PhilippineIdType(
    key: 'voters_id',
    displayName: "Voter's ID",
    requiresBack: true,
    icon: Icons.how_to_vote_outlined,
  ),
  PhilippineIdType(
    key: 'senior_citizen',
    displayName: 'Senior Citizen ID',
    requiresBack: false,
    icon: Icons.elderly_outlined,
  ),
  PhilippineIdType(
    key: 'tin',
    displayName: 'TIN ID',
    requiresBack: false,
    icon: Icons.numbers_outlined,
  ),
];

/// Result of an AI verification submission. Mirrors the JSON returned
/// by the `verify-identity` Edge Function plus the local error case.
class VerificationResult {
  /// 'approved' | 'manual_review' | 'rejected' | 'error'
  final String decision;
  final String? reason;
  final double? ocrConfidence;
  final double? faceMatchScore;
  final double? nameMatchScore;
  const VerificationResult({
    required this.decision,
    this.reason,
    this.ocrConfidence,
    this.faceMatchScore,
    this.nameMatchScore,
  });

  bool get isApproved => decision == 'approved';
  bool get isManualReview => decision == 'manual_review';
  bool get isRejected => decision == 'rejected';
  bool get isError => decision == 'error';
}

/// Whether the signed-in user has cleared identity verification.
/// Used to gate listing creation.
Future<bool> isCurrentUserVerified() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('is_verified')
        .eq('id', userId)
        .maybeSingle();
    return data != null && data['is_verified'] == true;
  } catch (e) {
    debugPrint('isCurrentUserVerified ERROR: $e');
    return false;
  }
}

/// Returns true if the current user has an active verification submission
/// that has not yet resolved (still pending AI processing, or awaiting an
/// admin's decision on a borderline AI result).
///
/// This trusts the `verifications` table — not the cached
/// `profiles.verification_decision` field, which can drift out of sync
/// when rows are deleted or when an admin manually flips `is_verified`
/// without touching the cached decision.
Future<bool> isUserVerificationPending() async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final profile = await client
        .from('profiles')
        .select('is_verified')
        .eq('id', userId)
        .maybeSingle();
    if (profile != null && profile['is_verified'] == true) return false;
    final latest = await client
        .from('verifications')
        .select('decision')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (latest == null) return false;
    final decision = latest['decision']?.toString();
    return decision == 'pending' || decision == 'manual_review';
  } catch (e) {
    debugPrint('isUserVerificationPending ERROR: $e');
    return false;
  }
}

/// Fetch the most recent verifications row for the current user (or null).
/// Drives the result screen + the profile status card's reason text.
Future<Map<String, dynamic>?> getLatestVerification() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await Supabase.instance.client
        .from('verifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  } catch (e) {
    debugPrint('getLatestVerification ERROR: $e');
    return null;
  }
}

/// Upload the user's ID (front + optional back) and selfie to the
/// private `verifications` bucket, insert a `verifications` row, and
/// invoke the `verify-identity` Edge Function. Returns the AI decision.
///
/// The Edge Function flips `profiles.is_verified` on approval; on
/// manual_review or rejection the profile is updated with the reason
/// but `is_verified` stays false.
Future<VerificationResult> submitUserVerification({
  required String idType,
  required Uint8List idFrontBytes,
  Uint8List? idBackBytes,
  required Uint8List selfieBytes,
}) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    return const VerificationResult(
      decision: 'error',
      reason: 'You must be signed in to verify.',
    );
  }

  try {
    // Upload first, then INSERT with the real paths. We can't INSERT
    // first and patch the paths later because the `verifications` table
    // restricts UPDATE to the service role (the Edge Function), so a
    // client-side UPDATE silently no-ops under RLS.
    final ts = DateTime.now().millisecondsSinceEpoch;
    final folder = '$userId/$ts';
    final frontPath = '$folder/front.jpg';
    final backPath = idBackBytes != null ? '$folder/back.jpg' : null;
    final selfiePath = '$folder/selfie.jpg';

    final uploads = <Future>[
      client.storage
          .from('verifications')
          .uploadBinary(frontPath, idFrontBytes),
      client.storage
          .from('verifications')
          .uploadBinary(selfiePath, selfieBytes),
      if (idBackBytes != null && backPath != null)
        client.storage
            .from('verifications')
            .uploadBinary(backPath, idBackBytes),
    ];
    await Future.wait(uploads);

    final inserted = await client
        .from('verifications')
        .insert({
          'user_id': userId,
          'id_type': idType,
          'id_front_path': frontPath,
          'id_back_path': backPath,
          'selfie_path': selfiePath,
        })
        .select('id')
        .single();
    final verificationId = inserted['id'] as String;

    await client
        .from('profiles')
        .update({
          'verification_id_url': frontPath,
          'verification_selfie_url': selfiePath,
          'verification_submitted_at': DateTime.now().toIso8601String(),
          'verification_id_type': idType,
          'verification_decision': null,
          'verification_rejection_reason': null,
        })
        .eq('id', userId);

    // Run the AI pipeline.
    final res = await client.functions.invoke(
      'verify-identity',
      body: {'verification_id': verificationId},
    );
    final data = (res.data as Map?)?.cast<String, dynamic>();
    if (data == null) {
      return const VerificationResult(
        decision: 'manual_review',
        reason:
            'Submission received but the AI check did not respond. '
            'An admin will review shortly.',
      );
    }
    if (data['error'] != null) {
      return VerificationResult(
        decision: 'manual_review',
        reason:
            'Submission received. Automated check error: ${data['error']}. '
            'An admin will review.',
      );
    }
    final scores = (data['scores'] as Map?)?.cast<String, dynamic>() ?? {};
    return VerificationResult(
      decision: data['decision']?.toString() ?? 'manual_review',
      reason: data['reason']?.toString(),
      ocrConfidence: (scores['ocr_confidence'] as num?)?.toDouble(),
      faceMatchScore: (scores['face_match_score'] as num?)?.toDouble(),
      nameMatchScore: (scores['name_match_score'] as num?)?.toDouble(),
    );
  } catch (e) {
    debugPrint('submitUserVerification ERROR: $e');
    return VerificationResult(
      decision: 'error',
      reason: 'Could not submit your verification: $e',
    );
  }
}

/// Levenshtein-based name similarity, normalized to 0..1. Mirrors the
/// `nameMatchScore` helper in the verify-identity Edge Function so the
/// client-side UI can preview likely outcomes if needed.
double nameMatchScore(String a, String b) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\b(jr|sr|ii|iii|iv|v)\b\.?'), '')
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final x = norm(a);
  final y = norm(b);
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  final m = x.length;
  final n = y.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = x[i - 1] == y[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  final dist = dp[m][n];
  final longest = m > n ? m : n;
  final score = 1 - dist / longest;
  return score < 0 ? 0 : score;
}

/// Upload a listing proof-of-ownership document to the private
/// `verifications` bucket. Returns the storage path on success.
Future<String?> uploadListingVerificationDoc({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final path = '$userId/listing_$ts.$ext';
    await client.storage.from('verifications').uploadBinary(path, bytes);
    return path;
  } catch (e) {
    debugPrint('uploadListingVerificationDoc ERROR: $e');
    return null;
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
Future<List<Property>> fetchLandlordListings({
  bool throwOnError = false,
}) async {
  try {
    // ignore: avoid_print
    print('fetchLandlordListings ENTER');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // ignore: avoid_print
      print('fetchLandlordListings NO USER');
      if (throwOnError) throw StateError('No authenticated user found.');
      return [];
    }
    final startedAt = DateTime.now();
    // ignore: avoid_print
    print('fetchLandlordListings START Supabase query');
    final data = await Supabase.instance.client
        .from('listings_full')
        .select(
          'id,title,city,barangay,full_address,monthly_rent,bedrooms,bathrooms,'
          'square_meters,cover_photo_url,latitude,longitude,property_type,'
          'description,furnishing,pets_allowed,smoking_allowed,landlord_id,created_at',
        )
        .eq('landlord_id', userId)
        .order('created_at', ascending: false);
    // ignore: avoid_print
    print(
      'fetchLandlordListings Supabase returned in '
      '${DateTime.now().difference(startedAt).inMilliseconds}ms',
    );
    final listings = (data as List)
        .map((row) => Property.fromMap(row as Map<String, dynamic>))
        .toList();
    // ignore: avoid_print
    print(
      'fetchLandlordListings END: ${listings.length} listings parsed in '
      '${DateTime.now().difference(startedAt).inMilliseconds}ms',
    );
    return listings;
  } catch (e, st) {
    // ignore: avoid_print
    print('fetchLandlordListings ERROR: $e');
    // ignore: avoid_print
    print('fetchLandlordListings STACK: $st');
    if (throwOnError) rethrow;
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
      client.from('listing_locations').insert({
        ...location,
        'listing_id': listingId,
      }),
      client.from('listing_details').insert({
        ...details,
        'listing_id': listingId,
      }),
      client.from('listing_amenities').insert({
        ...amenities,
        'listing_id': listingId,
      }),
      client.from('listing_utilities').insert({
        ...utilities,
        'listing_id': listingId,
      }),
      client.from('listing_building_features').insert({
        ...buildingFeatures,
        'listing_id': listingId,
      }),
      client.from('listing_financials').insert({
        ...financials,
        'listing_id': listingId,
      }),
      client.from('listing_availability').insert({
        ...availability,
        'listing_id': listingId,
      }),
      client.from('listing_policies').insert({
        ...policies,
        'listing_id': listingId,
      }),
      client.from('listing_requirements').insert({
        ...requirements,
        'listing_id': listingId,
      }),
      client.from('listing_host_info').insert({
        ...hostInfo,
        'listing_id': listingId,
      }),
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
      client
          .from('listing_locations')
          .update(location)
          .eq('listing_id', listingId),
      client
          .from('listing_details')
          .update(details)
          .eq('listing_id', listingId),
      client
          .from('listing_amenities')
          .update(amenities)
          .eq('listing_id', listingId),
      client
          .from('listing_utilities')
          .update(utilities)
          .eq('listing_id', listingId),
      client
          .from('listing_building_features')
          .update(buildingFeatures)
          .eq('listing_id', listingId),
      client
          .from('listing_financials')
          .update(financials)
          .eq('listing_id', listingId),
      client
          .from('listing_availability')
          .update(availability)
          .eq('listing_id', listingId),
      client
          .from('listing_policies')
          .update(policies)
          .eq('listing_id', listingId),
      client
          .from('listing_requirements')
          .update(requirements)
          .eq('listing_id', listingId),
      client
          .from('listing_host_info')
          .update(hostInfo)
          .eq('listing_id', listingId),
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

/// Save listing images to listing_image table.
/// Throws on failure so the caller can surface a meaningful error message.
Future<void> saveListingImages(
  String listingId,
  List<String> storagePaths, {
  String imageType = 'normal',
  String uploadSource = 'upload',
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final rows = storagePaths
      .asMap()
      .entries
      .map(
        (e) => {
          'listing_id': listingId,
          'url': e.value,
          'type': imageType,
          'upload_source': uploadSource,
          'sort_order': e.key,
          'is_cover': e.key == 0,
          'uploaded_by': userId,
        },
      )
      .toList();
  if (rows.isNotEmpty) {
    await Supabase.instance.client.from('listing_image').insert(rows);
  }
}

/// Delete a listing image by its ID
Future<bool> deleteListingImage(String imageId) async {
  try {
    await Supabase.instance.client
        .from('listing_image')
        .delete()
        .eq('id', imageId);
    return true;
  } catch (e) {
    debugPrint('deleteListingImage ERROR: $e');
    return false;
  }
}

/// Fetch all image records (with metadata) for a listing
Future<List<Map<String, dynamic>>> fetchListingImageRecords(
  String listingId,
) async {
  try {
    final data = await Supabase.instance.client
        .from('listing_image')
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
    await Supabase.instance.client.from('listing_image').insert({
      'listing_id': listingId,
      'url': storagePath,
      'type': 'panorama',
      'upload_source': uploadSource,
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
        .from('listing_image')
        .select()
        .eq('listing_id', listingId)
        .eq('type', 'panorama')
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
///
/// Returns `(id: <appId>, isReapplication: bool)` on success and throws on
/// failure. Mirrors the defensive checks in the web service
/// (`applicationsService.js#submitApplication`): re-verifies that the
/// listing is active+verified and that the tenant has finished identity
/// verification before doing any work. If a `rejected` application already
/// exists for the same `(listing_id, tenant_id)`, it is UPDATEd in place
/// (re-application) and stale document rows are cleared so the caller can
/// re-upload.
Future<({String id, bool isReapplication})> submitRentalApplicationV2({
  required String listingId,
  required String tenantId,
  required Map<String, dynamic> formRow,
}) async {
  final supa = Supabase.instance.client;

  // Listing gate
  final listing = await supa
      .from('listings')
      .select('id, status, is_verified, landlord_id')
      .eq('id', listingId)
      .maybeSingle();
  if (listing == null) {
    throw Exception('Listing not found.');
  }
  if ((listing['status']?.toString() ?? '') != 'active') {
    throw Exception('This listing is not currently accepting applications.');
  }
  if (listing['is_verified'] != true) {
    throw Exception(
      'This listing is pending verification and cannot accept applications yet.',
    );
  }

  // Tenant identity gate
  final tenant = await supa
      .from('profiles')
      .select('is_verified')
      .eq('id', tenantId)
      .maybeSingle();
  if (tenant == null || tenant['is_verified'] != true) {
    throw Exception('Please verify your identity before applying.');
  }

  // Duplicate guard
  final existing = await supa
      .from('application')
      .select('id, status')
      .eq('listing_id', listingId)
      .eq('tenant_id', tenantId)
      .maybeSingle();
  if (existing != null && existing['status'] != 'rejected') {
    final label = existing['status'] == 'pending'
        ? 'a pending application'
        : existing['status'] == 'approved'
            ? 'an approved application'
            : 'an existing application (${existing['status']})';
    throw Exception('You already have $label for this listing.');
  }

  final row = Map<String, dynamic>.from(formRow);
  row['listing_id'] = listingId;
  row['tenant_id'] = tenantId;
  row['landlord_id'] = listing['landlord_id'];
  row['status'] = 'pending';
  row['submitted_at'] ??= DateTime.now().toIso8601String();

  if (existing != null && existing['status'] == 'rejected') {
    final appId = existing['id'].toString();
    await supa
        .from('application_document')
        .delete()
        .eq('application_id', appId);
    await supa.from('application').update(row).eq('id', appId);
    return (id: appId, isReapplication: true);
  }

  final inserted = await supa
      .from('application')
      .insert(row)
      .select('id')
      .single();
  return (id: inserted['id'].toString(), isReapplication: false);
}

/// Save uploaded document paths for an application
Future<void> saveApplicationDocuments(
  String applicationId,
  List<Map<String, String>> docs,
) async {
  try {
    final rows = docs
        .map((d) => {'application_id': applicationId, ...d})
        .toList();
    if (rows.isNotEmpty) {
      await Supabase.instance.client.from('application_document').insert(rows);
      debugPrint('saveApplicationDocuments: inserted ${rows.length} rows');
    }
  } catch (e) {
    debugPrint('saveApplicationDocuments ERROR: $e');
    rethrow;
  }
}

/// Fetch applications for a specific listing (landlord side)
Future<List<Map<String, dynamic>>> fetchApplicationsForListing(
  String listingId,
) async {
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
  String applicationId,
) async {
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
  String applicationId,
) async {
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
  String applicationId,
  String status,
) async {
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
Future<Map<String, int>> fetchApplicationCounts(List<String> listingIds) async {
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

/// Returns the current tenant's application id+status for a listing, or
/// null if none. Used by unit_details to decide which CTA to show.
Future<({String id, String status})?> getMyApplicationForListing(
  String listingId,
) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await Supabase.instance.client
        .from('application')
        .select('id, status')
        .eq('listing_id', listingId)
        .eq('tenant_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return (
      id: data['id'].toString(),
      status: (data['status'] ?? 'pending').toString(),
    );
  } catch (e) {
    debugPrint('getMyApplicationForListing ERROR: $e');
    return null;
  }
}

// ─────────────────────────────────────────────
// CONTRACT (post-approval lease/rent agreement)
// ─────────────────────────────────────────────

/// Get-or-create the contract row for a given approved application.
/// On first call we create a row with status='awaiting_tenant' and
/// pre-populate the editor columns from `listing_financials`,
/// `listing_locations`, profile data, and the application row so the
/// landlord doesn't have to fill them in by hand. Mirrors the web
/// `buildContractFromApplication` flow.
Future<Map<String, dynamic>?> getOrCreateContract({
  required String applicationId,
  required String listingId,
  required String tenantId,
  required String landlordId,
}) async {
  if (applicationId.isEmpty ||
      listingId.isEmpty ||
      tenantId.isEmpty ||
      landlordId.isEmpty) {
    debugPrint(
      'getOrCreateContract: refusing call with empty id '
      '(application=$applicationId listing=$listingId '
      'tenant=$tenantId landlord=$landlordId)',
    );
    return null;
  }
  final supa = Supabase.instance.client;
  try {
    final existing = await supa
        .from('contract')
        .select()
        .eq('application_id', applicationId)
        .maybeSingle();
    if (existing != null) return Map<String, dynamic>.from(existing);

    // Pull listing_type + extras (financials, location, availability, title).
    final listing = await supa
        .from('listings')
        .select('listing_type, title, '
            'listing_financials(monthly_rent, security_deposit, advance_payment), '
            'listing_locations(full_address, city, province), '
            'listing_availability(lease_term, available_from)')
        .eq('id', listingId)
        .maybeSingle();
    final listingType = (listing?['listing_type'] ?? 'lease').toString();
    final fin = (listing?['listing_financials'] is List &&
            (listing!['listing_financials'] as List).isNotEmpty)
        ? Map<String, dynamic>.from((listing['listing_financials'] as List).first)
        : (listing?['listing_financials'] is Map
            ? Map<String, dynamic>.from(listing!['listing_financials'] as Map)
            : <String, dynamic>{});
    final loc = (listing?['listing_locations'] is List &&
            (listing!['listing_locations'] as List).isNotEmpty)
        ? Map<String, dynamic>.from((listing['listing_locations'] as List).first)
        : (listing?['listing_locations'] is Map
            ? Map<String, dynamic>.from(listing!['listing_locations'] as Map)
            : <String, dynamic>{});
    final avail = (listing?['listing_availability'] is List &&
            (listing!['listing_availability'] as List).isNotEmpty)
        ? Map<String, dynamic>.from(
            (listing['listing_availability'] as List).first)
        : (listing?['listing_availability'] is Map
            ? Map<String, dynamic>.from(
                listing!['listing_availability'] as Map)
            : <String, dynamic>{});

    // Optional: profile rows for party names + contacts. Wrapped in
    // try/catch because RLS on `profiles` may hide rows depending on
    // policy; the column being null is fine (landlord can fill later).
    Map<String, dynamic>? tenantProfile;
    Map<String, dynamic>? landlordProfile;
    try {
      tenantProfile = await supa
          .from('profiles')
          .select('full_name, phone')
          .eq('id', tenantId)
          .maybeSingle();
    } catch (_) {}
    try {
      landlordProfile = await supa
          .from('profiles')
          .select('full_name, phone')
          .eq('id', landlordId)
          .maybeSingle();
    } catch (_) {}

    final propertyAddress = (loc['full_address'] as String?) ??
        [loc['city'], loc['province']]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(', ');

    // Compute lease window from the listing's availability so the contract
    // view doesn't show '—' for the start / end dates. End date only applies
    // to fixed-term leases — month-to-month rentals leave it null.
    //
    // Defensive fallback: if a legacy listing lacks available_from we still
    // refuse to write a NULL start_date — the contract is being created now,
    // so today is the only defensible default. The enlistment form already
    // requires the field for new listings.
    final availableFromRaw = avail['available_from']?.toString();
    final startIso = (availableFromRaw != null && availableFromRaw.isNotEmpty)
        ? availableFromRaw.substring(0, 10)
        : DateTime.now().toIso8601String().substring(0, 10);
    String? endIso;
    if (listingType == 'lease') {
      final start = DateTime.tryParse(startIso);
      final termStr = (avail['lease_term'] ?? '').toString();
      final match = RegExp(r'(\d+)').firstMatch(termStr);
      final months = int.tryParse(match?.group(1) ?? '') ?? 12;
      if (start != null) {
        final end = DateTime(start.year, start.month + months, start.day);
        endIso = end.toIso8601String().substring(0, 10);
      }
    }

    final inserted = await supa
        .from('contract')
        .insert({
          'application_id': applicationId,
          'listing_id': listingId,
          'tenant_id': tenantId,
          'landlord_id': landlordId,
          'listing_type': listingType,
          'status': 'awaiting_tenant',
          'tenant_name': tenantProfile?['full_name'],
          'tenant_contact': tenantProfile?['phone'],
          'landlord_name': landlordProfile?['full_name'],
          'landlord_contact': landlordProfile?['phone'],
          'property_address': propertyAddress.isNotEmpty ? propertyAddress : null,
          'monthly_rent': fin['monthly_rent'],
          'security_deposit': fin['security_deposit'],
          'advance_rent': fin['advance_payment'],
          'duration': avail['lease_term'],
          'start_date': startIso,
          'end_date': endIso,
          'entered_on': DateTime.now().toIso8601String().substring(0, 10),
          'payment_due_date': 5,
          'grace_period_days': 5,
          'minor_repairs_threshold': 500,
          'overnight_guest_threshold': 7,
          'governing_city': loc['city'],
        })
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  } catch (e) {
    debugPrint('getOrCreateContract ERROR: $e');
    rethrow;
  }
}

/// Patch any of the editor columns on a contract row. Only an allow-list
/// of editable columns is forwarded — signatures and status transitions
/// have dedicated helpers (`signContractAs*`).
Future<bool> updateContract(
  String contractId,
  Map<String, dynamic> patch,
) async {
  const allowed = <String>{
    'listing_type',
    'landlord_name', 'landlord_contact', 'tenant_name', 'tenant_contact',
    'property_address', 'property_type', 'entered_on', 'start_date',
    'end_date', 'duration', 'monthly_rent', 'security_deposit',
    'advance_rent', 'payment_due_date', 'grace_period_days',
    'payment_method', 'account_info', 'late_fee',
    'minor_repairs_threshold', 'quiet_hours',
    'overnight_guest_threshold', 'governing_city',
  };
  final update = <String, dynamic>{
    'updated_at': DateTime.now().toIso8601String(),
  };
  for (final entry in patch.entries) {
    if (allowed.contains(entry.key)) update[entry.key] = entry.value;
  }
  if (update.length == 1) return true; // nothing to actually patch
  try {
    await Supabase.instance.client
        .from('contract')
        .update(update)
        .eq('id', contractId);
    return true;
  } catch (e) {
    debugPrint('updateContract ERROR: $e');
    return false;
  }
}

/// Fetch a single contract row by id, joining listings (for cover photo
/// / title / contract template URL) and the latest payment row.
Future<Map<String, dynamic>?> fetchContractById(String contractId) async {
  if (contractId.isEmpty) return null;
  try {
    final row = await Supabase.instance.client
        .from('contract')
        .select(
            '*, payment(*), listings(id, title, listing_type, contract_template_url, contract_template_name, terms_override)')
        .eq('id', contractId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  } catch (e) {
    debugPrint('fetchContractById ERROR: $e');
    return null;
  }
}

/// Persist the tenant's signature (raw stroke JSON + printed name).
/// Status becomes 'fully_signed' if the landlord has already signed,
/// otherwise 'awaiting_landlord'. Either party can sign first.
Future<bool> signContractAsTenant({
  required String contractId,
  required String signaturePayload,
  required String printedName,
}) async {
  try {
    final supa = Supabase.instance.client;
    final existing = await supa
        .from('contract')
        .select('landlord_signature')
        .eq('id', contractId)
        .maybeSingle();
    final landlordSigned =
        (existing?['landlord_signature']?.toString().isNotEmpty ?? false);
    await supa.from('contract').update({
      'tenant_signature': signaturePayload,
      'tenant_signed_name': printedName,
      'tenant_signed_at': DateTime.now().toIso8601String(),
      'status': landlordSigned ? 'fully_signed' : 'awaiting_landlord',
    }).eq('id', contractId);
    return true;
  } catch (e) {
    debugPrint('signContractAsTenant ERROR: $e');
    return false;
  }
}

/// Persist the landlord's signature. Status becomes 'fully_signed' if the
/// tenant has already signed, otherwise 'awaiting_tenant'.
Future<bool> signContractAsLandlord({
  required String contractId,
  required String signaturePayload,
  required String printedName,
}) async {
  try {
    final supa = Supabase.instance.client;
    final existing = await supa
        .from('contract')
        .select('tenant_signature')
        .eq('id', contractId)
        .maybeSingle();
    final tenantSigned =
        (existing?['tenant_signature']?.toString().isNotEmpty ?? false);
    await supa.from('contract').update({
      'landlord_signature': signaturePayload,
      'landlord_signed_name': printedName,
      'landlord_signed_at': DateTime.now().toIso8601String(),
      'status': tenantSigned ? 'fully_signed' : 'awaiting_tenant',
    }).eq('id', contractId);
    return true;
  } catch (e) {
    debugPrint('signContractAsLandlord ERROR: $e');
    return false;
  }
}

// ─────────────────────────────────────────────
// REPORTS (maintenance / cleaning / etc.)
// ─────────────────────────────────────────────

/// Submit a new report. Tenant-only (RLS enforces auth.uid()=tenant_id).
/// Returns the inserted row id, or null on failure.
Future<String?> submitReport({
  required String contractId,
  required String listingId,
  required String tenantId,
  required String landlordId,
  required String type,
  required String priority,
  required String title,
  String? description,
}) async {
  try {
    await Supabase.instance.client.from('report').insert({
      'contract_id': contractId,
      'listing_id': listingId,
      'tenant_id': tenantId,
      'landlord_id': landlordId,
      'type': type,
      'priority': priority,
      'title': title,
      'description': description,
      'status': 'open',
    });
    return 'ok';
  } catch (e) {
    debugPrint('submitReport ERROR: $e');
    return null;
  }
}

/// Update a report's status.
Future<bool> updateReportStatus({
  required String reportId,
  required String
  newStatus, // 'open' | 'in_progress' | 'resolved' | 'cancelled'
}) async {
  try {
    final patch = <String, dynamic>{'status': newStatus};
    if (newStatus == 'resolved') {
      patch['resolved_at'] = DateTime.now().toIso8601String();
    }
    await Supabase.instance.client
        .from('report')
        .update(patch)
        .eq('id', reportId);
    return true;
  } catch (e) {
    debugPrint('updateReportStatus ERROR: $e');
    return false;
  }
}

/// Landlord posts a response message on a report.
Future<bool> respondToReport({
  required String reportId,
  required String response,
}) async {
  try {
    await Supabase.instance.client
        .from('report')
        .update({
          'landlord_response': response,
          'landlord_responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reportId);
    return true;
  } catch (e) {
    debugPrint('respondToReport ERROR: $e');
    return false;
  }
}

/// Tenant-side report list — every report this tenant has filed.
Future<List<Map<String, dynamic>>> fetchMyReports() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('report')
        .select(
          'id, type, priority, status, title, description, '
          'landlord_response, landlord_responded_at, resolved_at, '
          'created_at, listing_id, contract_id, '
          'listings(title)',
        )
        .eq('tenant_id', userId)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchMyReports ERROR: $e');
    return [];
  }
}

/// Landlord-side report queue — all reports against this landlord's units.
/// Tenant profile is batch-fetched and merged in as [tenant_profile].
Future<List<Map<String, dynamic>>> fetchLandlordReports() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await Supabase.instance.client
        .from('report')
        .select(
          'id, type, priority, status, title, description, '
          'landlord_response, landlord_responded_at, resolved_at, '
          'created_at, listing_id, contract_id, tenant_id, '
          'listings(title)',
        )
        .eq('landlord_id', userId)
        .order('created_at', ascending: false);
    final reports = (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    // Batch-fetch tenant profiles for name + avatar display.
    final tenantIds = reports
        .map((r) => r['tenant_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (tenantIds.isNotEmpty) {
      try {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', tenantIds);
        final byId = <String, Map<String, dynamic>>{
          for (final p in (profiles as List))
            (p as Map)['id'].toString(): Map<String, dynamic>.from(p),
        };
        for (final r in reports) {
          final tid = r['tenant_id']?.toString();
          if (tid != null) r['tenant_profile'] = byId[tid] ?? {};
        }
      } catch (_) {}
    }
    return reports;
  } catch (e) {
    debugPrint('fetchLandlordReports ERROR: $e');
    return [];
  }
}

/// The tenant's currently-active rental — the most recent contract
/// with status='paid'. Includes pricing + listing core fields so the
/// in-stay dashboard can render move-in info, next due date, etc.
Future<Map<String, dynamic>?> fetchMyActiveRental() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final contract = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, listing_id, application_id, listing_type, '
          'tenant_signed_at, landlord_signed_at, '
          'listings(id, title, landlord_id)',
        )
        .eq('tenant_id', userId)
        .eq('status', 'paid')
        .order('landlord_signed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (contract == null) return null;
    final c = Map<String, dynamic>.from(contract);
    final listingId = c['listing_id']?.toString();
    if (listingId != null) {
      final listingData = await Supabase.instance.client
          .from('listings_full')
          .select(
            'monthly_rent, security_deposit, advance_payment, '
            'available_from, lease_term, full_address, city, province',
          )
          .eq('id', listingId)
          .maybeSingle();
      if (listingData != null) c.addAll(Map<String, dynamic>.from(listingData));
    }
    final mostRecentPayment = await Supabase.instance.client
        .from('payment')
        .select('paid_at, amount_cents')
        .eq('contract_id', c['id'])
        .order('paid_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (mostRecentPayment != null) {
      c['last_paid_at'] = mostRecentPayment['paid_at'];
      c['last_paid_cents'] = mostRecentPayment['amount_cents'];
    }
    return c;
  } catch (e) {
    debugPrint('fetchMyActiveRental ERROR: $e');
    return null;
  }
}

/// Landlord's active tenants — every contract with status='paid' the
/// landlord owns, joined with tenant info from the application row.
/// Each row also gets a `tenant_profile` map with avatar_url + full_name
/// pulled in a follow-up batched query (Supabase doesn't auto-join the
/// auth-user backed `profiles` table through `tenant_id` on `contract`).
Future<List<Map<String, dynamic>>> fetchActiveTenants() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, tenant_id, listing_id, application_id, '
          'tenant_signed_at, landlord_signed_at, '
          'listings(title), '
          'application(first_name, last_name, email, phone_number)',
        )
        .eq('landlord_id', userId)
        .eq('status', 'paid')
        .order('landlord_signed_at', ascending: false);
    // Supabase rows can be unmodifiable — copy each into a mutable map
    // so we can splice the joined profile in.
    final rows = (data as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    // Batch-fetch tenant profile rows for avatars.
    final tenantIds = rows
        .map((r) => r['tenant_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (tenantIds.isNotEmpty) {
      try {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', tenantIds);
        final byId = <String, Map<String, dynamic>>{
          for (final p in (profiles as List))
            (p as Map)['id'].toString(): Map<String, dynamic>.from(p),
        };
        for (final r in rows) {
          final tid = r['tenant_id']?.toString();
          if (tid != null && byId[tid] != null) {
            r['tenant_profile'] = byId[tid];
          }
        }
      } catch (e) {
        debugPrint('fetchActiveTenants profile join ERROR: $e');
      }
    }
    return rows;
  } catch (e) {
    debugPrint('fetchActiveTenants ERROR: $e');
    return [];
  }
}

/// The next contract the tenant should pay — first row with
/// status='fully_signed' (and not yet paid) ordered by signing date.
/// Returns null when nothing is due.
Future<Map<String, dynamic>?> fetchMyNextDueContract() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, listing_id, application_id, '
          'landlord_signed_at, listing_type, '
          'listings(id, title)',
        )
        .eq('tenant_id', userId)
        .eq('status', 'fully_signed')
        .order('landlord_signed_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    final c = Map<String, dynamic>.from(data);
    final listingId = c['listing_id']?.toString();
    if (listingId != null) {
      final listingData = await Supabase.instance.client
          .from('listings_full')
          .select('monthly_rent, security_deposit, advance_payment')
          .eq('id', listingId)
          .maybeSingle();
      if (listingData != null) c.addAll(Map<String, dynamic>.from(listingData));
    }
    return c;
  } catch (e) {
    debugPrint('fetchMyNextDueContract ERROR: $e');
    return null;
  }
}

/// Landlord's contract queue — every contract where they are the
/// landlord party. Drives the Tenant Contracts inbox on the landlord
/// profile.
Future<List<Map<String, dynamic>>> fetchLandlordContracts() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, listing_id, application_id, '
          'tenant_signed_at, landlord_signed_at, listing_type, '
          'listings(id, title), '
          'application(first_name, last_name)',
        )
        .eq('landlord_id', userId)
        .order('tenant_signed_at', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('fetchLandlordContracts ERROR: $e');
    return [];
  }
}

/// Tenant's full application list with the listing title joined in,
/// plus the matching contract row (if any) attached as `contract`.
/// Drives the My Applications inbox screen — the contract status decides
/// which CTA each approved row shows (Sign / Awaiting landlord / Pay /
/// View active rental). Mirrors `fetchTenantApplications` in the web
/// service.
Future<List<Map<String, dynamic>>> fetchMyApplicationsWithListing() async {
  try {
    final supa = Supabase.instance.client;
    final userId = supa.auth.currentUser?.id;
    if (userId == null) return [];

    final apps = await supa
        .from('application')
        .select(
          'id, status, submitted_at, listing_id, '
          'listings(id, title, landlord_id, '
          'listing_financials(monthly_rent, security_deposit, advance_payment), '
          'listing_locations(full_address, city, province))',
        )
        .eq('tenant_id', userId)
        .order('submitted_at', ascending: false);

    final rows = (apps as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return rows;

    // Two queries because no FK is declared between application and
    // contract for PostgREST to traverse.
    final appIds = rows.map((r) => r['id'].toString()).toList();
    final contracts = await supa
        .from('contract')
        .select('id, status, application_id')
        .inFilter('application_id', appIds);

    final byApp = <String, Map<String, dynamic>>{};
    for (final c in (contracts as List).cast<Map<String, dynamic>>()) {
      final aid = c['application_id']?.toString();
      if (aid != null) byApp[aid] = c;
    }

    for (final r in rows) {
      r['contract'] = byApp[r['id'].toString()];
    }
    return rows;
  } catch (e) {
    debugPrint('fetchMyApplicationsWithListing ERROR: $e');
    return [];
  }
}

/// Fetch a single application belonging to the tenant, in camelCase
/// shape suitable for pre-filling the edit form. Returns null if the
/// row doesn't belong to this tenant. Mirrors
/// `fetchApplicationForTenant` in the web service.
Future<Map<String, dynamic>?> fetchApplicationForTenant(
  String applicationId,
  String tenantId,
) async {
  try {
    final data = await Supabase.instance.client
        .from('application')
        .select(
          'id, listing_id, status, submitted_at, '
          'first_name, last_name, phone_number, email, date_of_birth, '
          'current_address, employment_status, job_title, company_name, '
          'monthly_income, employment_length, work_address, '
          'previous_address, stayed_duration, reason_for_leaving, '
          'previous_landlord, landlord_contact, '
          'agreed_to_declaration, declaration_name',
        )
        .eq('id', applicationId)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    if (data == null) return null;

    final firstName = (data['first_name'] ?? '').toString();
    final lastName = (data['last_name'] ?? '').toString();
    final fullName = [firstName, lastName]
        .where((s) => s.isNotEmpty)
        .join(' ');

    return {
      'id': data['id'],
      'listingId': data['listing_id'],
      'status': data['status'],
      'submittedAt': data['submitted_at'],
      'fullName': fullName,
      'dateOfBirth': data['date_of_birth'] ?? '',
      'contactNumber': data['phone_number'] ?? '',
      'email': data['email'] ?? '',
      'currentAddress': data['current_address'] ?? '',
      'employmentStatus': data['employment_status'] ?? '',
      'jobTitle': data['job_title'] ?? '',
      'companyName': data['company_name'] ?? '',
      'monthlyIncome': data['monthly_income'] == null
          ? ''
          : data['monthly_income'].toString(),
      'lengthOfEmployment': data['employment_length'] ?? '',
      'workAddress': data['work_address'] ?? '',
      'previousAddress': data['previous_address'] ?? '',
      'rentalDuration': data['stayed_duration'] ?? '',
      'reasonForLeaving': data['reason_for_leaving'] ?? '',
      'landlordName': data['previous_landlord'] ?? '',
      'landlordPhone': data['landlord_contact'] ?? '',
      'consentIdentity': data['agreed_to_declaration'] == true,
    };
  } catch (e) {
    debugPrint('fetchApplicationForTenant ERROR: $e');
    return null;
  }
}

/// Update editable fields on a tenant's PENDING application. Mirrors
/// `updateApplication` in the web service: re-checks the status
/// server-side so a tenant can't sneak edits in after a landlord has
/// approved/rejected — even if the UI is bypassed. Throws on failure.
Future<void> updateApplicationForTenant({
  required String applicationId,
  required String tenantId,
  required Map<String, dynamic> patch,
}) async {
  final supa = Supabase.instance.client;

  final gate = await supa
      .from('application')
      .select('status, tenant_id')
      .eq('id', applicationId)
      .maybeSingle();
  if (gate == null) {
    throw Exception('Application not found.');
  }
  if (gate['tenant_id'] != tenantId) {
    throw Exception('Not your application.');
  }
  if (gate['status'] != 'pending') {
    throw Exception('This application can no longer be edited.');
  }

  final fullName = (patch['fullName'] ?? '').toString().trim();
  final parts = fullName.isEmpty
      ? <String>[]
      : fullName.split(RegExp(r'\s+'));
  final firstName = parts.isNotEmpty ? parts.first : null;
  final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

  String? trimOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double? toNumOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  final update = <String, dynamic>{
    'first_name': firstName,
    'last_name': lastName,
    'phone_number': trimOrNull(patch['contactNumber']),
    'email': trimOrNull(patch['email']),
    'date_of_birth': trimOrNull(patch['dateOfBirth']),
    'current_address': trimOrNull(patch['currentAddress']),
    'employment_status': trimOrNull(patch['employmentStatus']),
    'job_title': trimOrNull(patch['jobTitle']),
    'company_name': trimOrNull(patch['companyName']),
    'monthly_income': toNumOrNull(patch['monthlyIncome']),
    'employment_length': trimOrNull(patch['lengthOfEmployment']),
    'work_address': trimOrNull(patch['workAddress']),
    'previous_address': trimOrNull(patch['previousAddress']),
    'stayed_duration': trimOrNull(patch['rentalDuration']),
    'reason_for_leaving': trimOrNull(patch['reasonForLeaving']),
    'previous_landlord': trimOrNull(patch['landlordName']),
    'landlord_contact': trimOrNull(patch['landlordPhone']),
    'agreed_to_declaration': patch['consentIdentity'] == true,
    'declaration_name': fullName.isEmpty ? null : fullName,
  };

  await supa
      .from('application')
      .update(update)
      .eq('id', applicationId)
      .eq('tenant_id', tenantId);
}

// ─── Chat / conversations ────────────────────────────────────────
//
// Schema: see supabase/migrations/chat_module.sql
//   conversation (id, landlord_id, tenant_id, listing_id?,
//                 last_message, last_message_at, is_archived,
//                 created_at)
//   message      (id, conversation_id, sender_id, type,
//                 content, url, file_name, is_read, created_at)
//
// Convention: caller passes (landlordId, tenantId) and the other
// party is identified relative to the current user.

/// Find an existing conversation between the two users (and an
/// optional listing context) or create one. Returns the conversation
/// id. Either party may call this.
Future<String?> getOrCreateConversation({
  required String landlordId,
  required String tenantId,
  String? listingId,
}) async {
  try {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return null;
    if (me != landlordId && me != tenantId) return null;

    var query = client
        .from('conversation')
        .select('id')
        .eq('landlord_id', landlordId)
        .eq('tenant_id', tenantId);
    query = listingId == null
        ? query.isFilter('listing_id', null)
        : query.eq('listing_id', listingId);
    final existing = await query.maybeSingle();
    if (existing != null) return existing['id']?.toString();

    final inserted = await client
        .from('conversation')
        .insert({
          'landlord_id': landlordId,
          'tenant_id': tenantId,
          'listing_id': ?listingId,
        })
        .select('id')
        .single();
    return inserted['id']?.toString();
  } catch (e) {
    debugPrint('getOrCreateConversation ERROR: $e');
    return null;
  }
}

/// All conversations the current user participates in, decorated
/// with the *other* party's profile (full_name, avatar_url) and the
/// optional listing title. Drives the conversations inbox.
Future<List<Map<String, dynamic>>> fetchMyConversations() async {
  try {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return [];

    final data = await client
        .from('conversation')
        .select(
          'id, landlord_id, tenant_id, listing_id, '
          'last_message, last_message_at, is_archived, created_at',
        )
        .or('landlord_id.eq.$me,tenant_id.eq.$me')
        .order('last_message_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    final rows = (data as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    // Resolve listing titles via a secondary fetch against the
    // `listings_full` view (replaces the legacy `listings_old` table).
    final listingIds = rows
        .map((r) => r['listing_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (listingIds.isNotEmpty) {
      try {
        final listings = await client
            .from('listings_full')
            .select('id, title')
            .inFilter('id', listingIds);
        final byId = <String, String>{
          for (final l in (listings as List))
            (l as Map)['id'].toString(): (l['title'] ?? '').toString(),
        };
        for (final r in rows) {
          final lid = r['listing_id']?.toString();
          if (lid != null && byId[lid] != null) {
            r['listing_title'] = byId[lid];
          }
        }
      } catch (e) {
        debugPrint('fetchMyConversations listing join ERROR: $e');
      }
    }

    // Resolve "the other party" id per row, then batch-fetch profiles.
    final otherIds = <String>{
      for (final r in rows)
        (r['landlord_id'].toString() == me ? r['tenant_id'] : r['landlord_id'])
            .toString(),
    }.toList();
    if (otherIds.isNotEmpty) {
      try {
        final profiles = await client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', otherIds);
        final byId = <String, Map<String, dynamic>>{
          for (final p in (profiles as List))
            (p as Map)['id'].toString(): Map<String, dynamic>.from(p),
        };
        for (final r in rows) {
          final otherId =
              (r['landlord_id'].toString() == me
                      ? r['tenant_id']
                      : r['landlord_id'])
                  .toString();
          r['other_id'] = otherId;
          r['other_profile'] = byId[otherId] ?? {};
        }
      } catch (e) {
        debugPrint('fetchMyConversations profile join ERROR: $e');
      }
    }

    // Unread counts: messages addressed to me (sender != me) with
    // is_read = false. One round-trip — small enough to do per row.
    for (final r in rows) {
      try {
        final unread = await client
            .from('message')
            .select('id')
            .eq('conversation_id', r['id'])
            .neq('sender_id', me)
            .eq('is_read', false);
        r['unread_count'] = (unread as List).length;
      } catch (_) {
        r['unread_count'] = 0;
      }
    }
    return rows;
  } catch (e) {
    debugPrint('fetchMyConversations ERROR: $e');
    return [];
  }
}

/// Realtime stream of messages for a conversation, oldest first.
/// Drives the chat thread view.
Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
  return Supabase.instance.client
      .from('message')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true);
}

/// Insert a text message into a conversation as the current user.
/// Returns true on success.
Future<bool> sendMessage({
  required String conversationId,
  required String body,
}) async {
  try {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return false;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;
    await Supabase.instance.client.from('message').insert({
      'conversation_id': conversationId,
      'sender_id': me,
      'type': 'text',
      'content': trimmed,
    });
    return true;
  } catch (e) {
    debugPrint('sendMessage ERROR: $e');
    return false;
  }
}

/// Upload `bytes` to the `chat-attachments` storage bucket and
/// insert a message row referencing it. `messageType` is 'image' or
/// 'file' — the bubble renderer keys off this.
///
/// Storage layout: `chat-attachments/{conversationId}/{ts}_{safeName}`
///
/// Required setup (one-time, in Supabase dashboard):
///   1. Create a public bucket named `chat-attachments`.
///   2. Add storage policy:
///        bucket_id = 'chat-attachments'
///        AND auth.role() = 'authenticated'
///      for INSERT and SELECT.
Future<bool> sendAttachmentMessage({
  required String conversationId,
  required Uint8List bytes,
  required String fileName,
  required String messageType,
}) async {
  try {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return false;
    if (messageType != 'image' && messageType != 'file') return false;

    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$me/$conversationId/${ts}_$safe';

    await Supabase.instance.client.storage
        .from('chat-attachments')
        .uploadBinary(path, bytes);

    final url = Supabase.instance.client.storage
        .from('chat-attachments')
        .getPublicUrl(path);

    await Supabase.instance.client.from('message').insert({
      'conversation_id': conversationId,
      'sender_id': me,
      'type': messageType,
      'url': url,
      'file_name': fileName,
    });
    return true;
  } catch (e) {
    debugPrint('sendAttachmentMessage ERROR: $e');
    return false;
  }
}

/// Mark all messages from the *other* party in this conversation as
/// read. Idempotent.
Future<void> markConversationRead(String conversationId) async {
  try {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    await Supabase.instance.client
        .from('message')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', me)
        .eq('is_read', false);
  } catch (e) {
    debugPrint('markConversationRead ERROR: $e');
  }
}

// ─────────────────────────────────────────────
// POST-RENT FLOW (termination, move-out, close)
// ─────────────────────────────────────────────

/// Active rental status set — used to scope queries beyond just 'paid'.
const _activeRentalStatuses = [
  'paid',
  'terminating',
  'expiring',
  'terminated',
  'ended',
];

/// Fetch the tenant's active-or-terminating contract.
/// Replaces the narrow `status='paid'` filter with the full status set.
Future<Map<String, dynamic>?> fetchMyActiveContract() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final contract = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, listing_id, application_id, listing_type, '
          'tenant_signed_at, landlord_signed_at, start_date, end_date, '
          'listings(id, title, landlord_id)',
        )
        .eq('tenant_id', userId)
        .inFilter('status', _activeRentalStatuses)
        .order('landlord_signed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (contract == null) return null;
    final c = Map<String, dynamic>.from(contract);
    final listingId = c['listing_id']?.toString();
    if (listingId != null) {
      // Use listings_full view — it is readable by all authenticated users
      // (same RLS as the public listings feed). Querying the sub-tables
      // directly (listing_financials, listing_availability, listing_locations)
      // can silently fail for tenants who are also landlords due to sub-table
      // RLS policies scoped to the listing owner only.
      final listingData = await Supabase.instance.client
          .from('listings_full')
          .select(
            'monthly_rent, security_deposit, advance_payment, '
            'available_from, lease_term, full_address, city, province',
          )
          .eq('id', listingId)
          .maybeSingle();
      if (listingData != null) c.addAll(Map<String, dynamic>.from(listingData));
    }
    final mostRecentPayment = await Supabase.instance.client
        .from('payment')
        .select('paid_at, amount_cents')
        .eq('contract_id', c['id'])
        .order('paid_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (mostRecentPayment != null) {
      c['last_paid_at'] = mostRecentPayment['paid_at'];
      c['last_paid_cents'] = mostRecentPayment['amount_cents'];
    }
    return c;
  } catch (e) {
    debugPrint('fetchMyActiveContract ERROR: $e');
    return null;
  }
}

/// Fetch the contract_termination row for a contract.
Future<Map<String, dynamic>?> getTermination(String contractId) async {
  try {
    final data = await Supabase.instance.client
        .from('contract_termination')
        .select('*')
        .eq('contract_id', contractId)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  } catch (e) {
    debugPrint('getTermination ERROR: $e');
    return null;
  }
}

/// Fetch deductions for a termination row.
Future<List<Map<String, dynamic>>> getDeductions(String terminationId) async {
  try {
    final data = await Supabase.instance.client
        .from('contract_deduction')
        .select('*')
        .eq('termination_id', terminationId);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('getDeductions ERROR: $e');
    return [];
  }
}

/// Full termination state: contract + termination + deductions + open reports.
/// Returns a map with keys: contract, termination, deductions, openReports, totals.
Future<Map<String, dynamic>> getTerminationState(String contractId) async {
  // Load contract by id — RLS (contract_select_party) scopes this to the
  // tenant or landlord on the row, so it works for both parties. The
  // Move-Out Checklist screen is landlord-only and cannot rely on
  // fetchMyActiveContract (that helper filters by tenant_id = auth.uid()).
  Map<String, dynamic>? contract;
  try {
    final row = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, listing_id, tenant_id, landlord_id, application_id, '
          'listing_type, tenant_signed_at, landlord_signed_at, '
          'start_date, end_date, security_deposit, effective_end_date',
        )
        .eq('id', contractId)
        .maybeSingle();
    if (row != null) {
      final c = Map<String, dynamic>.from(row);
      final listingId = c['listing_id']?.toString();
      if (listingId != null) {
        try {
          final listingData = await Supabase.instance.client
              .from('listings_full')
              .select(
                'monthly_rent, security_deposit, advance_payment, '
                'available_from, lease_term, full_address, city, province',
              )
              .eq('id', listingId)
              .maybeSingle();
          if (listingData != null) {
            // Don't let a null listing column clobber a non-null contract column.
            for (final entry in Map<String, dynamic>.from(listingData).entries) {
              if (entry.value != null) c[entry.key] = entry.value;
            }
          }
        } catch (e) {
          debugPrint('getTerminationState listing enrich ERROR: $e');
        }
      }
      contract = c;
    }
  } catch (e) {
    debugPrint('getTerminationState contract fetch ERROR: $e');
  }

  final termination = await getTermination(contractId);
  List<Map<String, dynamic>> deductions = [];
  if (termination != null) {
    deductions = await getDeductions(termination['id'].toString());
  }
  final openReportsData = await Supabase.instance.client
      .from('report')
      .select('id, title, status')
      .eq('contract_id', contractId)
      .inFilter('status', ['open', 'in_progress']);
  final openReports = (openReportsData as List).cast<Map<String, dynamic>>();

  final securityDeposit =
      (termination?['security_deposit_amount'] as num?)?.toDouble() ??
      (contract?['security_deposit'] as num?)?.toDouble() ??
      0.0;
  final totalDeductions = deductions.fold<double>(
    0.0,
    (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0),
  );
  final amountReturned = (securityDeposit - totalDeductions).clamp(
    0.0,
    double.infinity,
  );

  return {
    'contract': contract,
    'termination': termination,
    'deductions': deductions,
    'openReports': openReports,
    'totals': {
      'securityDeposit': securityDeposit,
      'totalDeductions': totalDeductions,
      'amountReturned': amountReturned,
    },
  };
}

/// Evaluate the 4 move-out gates needed before Close Contract is allowed.
Map<String, dynamic> evaluateMoveOutGates({
  required Map<String, dynamic>? contract,
  required Map<String, dynamic>? termination,
  required List<Map<String, dynamic>> openReports,
  double outstandingBalance = 0.0,
}) {
  const terminatingStatuses = {'terminating', 'ended'};
  final contractStatus = contract?['status']?.toString() ?? '';
  final statusOk = terminatingStatuses.contains(contractStatus);
  final tenantVacated = termination?['tenant_vacated_confirmed_at'] != null;
  final reportsCarryOver = termination?['reports_carry_over_ack'] == true;
  final reportsClear = openReports.isEmpty || reportsCarryOver;
  final balanceWaived = termination?['outstanding_balance_waived'] == true;
  final balanceClear = outstandingBalance <= 0 || balanceWaived;
  final canClose = statusOk && tenantVacated && reportsClear && balanceClear;
  return {
    'statusOk': statusOk,
    'tenantVacated': tenantVacated,
    'reportsClear': reportsClear,
    'balanceClear': balanceClear,
    'canClose': canClose,
  };
}

/// Request a contract termination.
/// [type]: 'notice' (MTM 30-day), 'mutual' (fixed-term), 'non_renewal', 'eviction'
/// [initiatedBy]: 'tenant' or 'landlord'
Future<bool> requestTermination({
  required String contractId,
  required String type,
  required String initiatedBy,
  required DateTime noticeDate,
  required DateTime effectiveDate,
  String? reason,
  double? securityDepositAmount,
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;

    // contract_termination has UNIQUE (contract_id). A superseded row
    // (withdrawn mutual or landlord-closed) blocks a fresh insert, so
    // delete it first. An open active row means a request is already in
    // flight — bail out so the caller can surface that to the user.
    final existing = await getTermination(contractId);
    if (existing != null) {
      final isSuperseded = existing['mutual_withdrawn_at'] != null ||
          existing['landlord_closed_at'] != null;
      if (!isSuperseded) {
        debugPrint(
            'requestTermination skipped: open termination already exists for $contractId');
        return false;
      }
      await Supabase.instance.client
          .from('contract_termination')
          .delete()
          .eq('id', existing['id']);
      await _logContractEvent(
        contractId: contractId,
        actorId: actorId,
        eventType: 'termination_superseded',
        payload: {
          'previous_termination_id': existing['id'],
          'previous_type': existing['type'],
          'previous_initiated_by': existing['initiated_by'],
        },
      );
    }

    await Supabase.instance.client.from('contract_termination').insert({
      'contract_id': contractId,
      'initiated_by': initiatedBy,
      'type': type,
      'notice_date': noticeDate.toIso8601String(),
      'effective_date': effectiveDate.toIso8601String(),
      'reason': ?reason,
      'security_deposit_amount': ?securityDepositAmount,
      if (type == 'mutual')
        'mutual_proposed_at': DateTime.now().toIso8601String(),
      if (type == 'mutual' && initiatedBy == 'tenant')
        'mutual_accepted_by_tenant_at': DateTime.now().toIso8601String(),
      if (type == 'mutual' && initiatedBy == 'landlord')
        'mutual_accepted_by_landlord_at': DateTime.now().toIso8601String(),
    });

    // For non-mutual types, flip contract status immediately.
    if (type != 'mutual') {
      final newStatus = type == 'non_renewal' ? 'expiring' : 'terminating';
      await Supabase.instance.client
          .from('contract')
          .update({
            'status': newStatus,
            'effective_end_date': effectiveDate.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', contractId);
    }

    await _logContractEvent(
      contractId: contractId,
      actorId: actorId,
      eventType: type == 'mutual'
          ? 'termination_mutual_requested'
          : 'termination_notice_requested',
      payload: {'type': type, 'initiated_by': initiatedBy},
    );
    return true;
  } catch (e) {
    debugPrint('requestTermination ERROR: $e');
    return false;
  }
}

/// Accept the mutual termination proposal (called by whichever side did NOT propose).
Future<bool> acceptMutualTermination({
  required String contractId,
  required String terminationId,
  required String acceptingRole, // 'tenant' or 'landlord'
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;

    final now = DateTime.now().toIso8601String();
    final field = acceptingRole == 'tenant'
        ? 'mutual_accepted_by_tenant_at'
        : 'mutual_accepted_by_landlord_at';

    await Supabase.instance.client
        .from('contract_termination')
        .update({field: now})
        .eq('id', terminationId);

    // Re-fetch to check if both sides have now accepted.
    final updated = await Supabase.instance.client
        .from('contract_termination')
        .select(
          'mutual_accepted_by_tenant_at, mutual_accepted_by_landlord_at, effective_date',
        )
        .eq('id', terminationId)
        .single();

    final bothAccepted =
        updated['mutual_accepted_by_tenant_at'] != null &&
        updated['mutual_accepted_by_landlord_at'] != null;

    if (bothAccepted) {
      await Supabase.instance.client
          .from('contract')
          .update({
            'status': 'terminating',
            'effective_end_date': updated['effective_date'],
            'updated_at': now,
          })
          .eq('id', contractId);

      await _logContractEvent(
        contractId: contractId,
        actorId: actorId,
        eventType: 'termination_mutual_accepted',
        payload: {'accepting_role': acceptingRole},
      );
    } else {
      await _logContractEvent(
        contractId: contractId,
        actorId: actorId,
        eventType: 'termination_mutual_partial_accept',
        payload: {'accepting_role': acceptingRole},
      );
    }
    return true;
  } catch (e) {
    debugPrint('acceptMutualTermination ERROR: $e');
    return false;
  }
}

/// Withdraw a mutual termination proposal before the other side accepts.
Future<bool> withdrawMutualTermination({
  required String contractId,
  required String terminationId,
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;
    await Supabase.instance.client
        .from('contract_termination')
        .update({'mutual_withdrawn_at': DateTime.now().toIso8601String()})
        .eq('id', terminationId);
    await _logContractEvent(
      contractId: contractId,
      actorId: actorId,
      eventType: 'termination_mutual_withdrawn',
      payload: {},
    );
    return true;
  } catch (e) {
    debugPrint('withdrawMutualTermination ERROR: $e');
    return false;
  }
}

/// Tenant confirms they have vacated.
Future<bool> confirmTenantVacated({
  required String contractId,
  required String terminationId,
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;
    // Idempotent — skip if already set.
    final existing = await Supabase.instance.client
        .from('contract_termination')
        .select('tenant_vacated_confirmed_at')
        .eq('id', terminationId)
        .single();
    if (existing['tenant_vacated_confirmed_at'] != null) return true;

    await Supabase.instance.client
        .from('contract_termination')
        .update({
          'tenant_vacated_confirmed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', terminationId);
    await _logContractEvent(
      contractId: contractId,
      actorId: actorId,
      eventType: 'tenant_vacated_confirmed',
      payload: {},
    );
    return true;
  } catch (e) {
    debugPrint('confirmTenantVacated ERROR: $e');
    return false;
  }
}

/// Add a security deposit deduction item.
Future<bool> addDeduction({
  required String terminationId,
  required String category,
  required String description,
  required double amount,
  String? photoUrl,
}) async {
  try {
    await Supabase.instance.client.from('contract_deduction').insert({
      'termination_id': terminationId,
      'category': category,
      'description': description,
      'amount': amount,
      'photo_url': ?photoUrl,
    });
    return true;
  } catch (e) {
    debugPrint('addDeduction ERROR: $e');
    return false;
  }
}

/// Remove a deduction item.
Future<bool> removeDeduction(String deductionId) async {
  try {
    await Supabase.instance.client
        .from('contract_deduction')
        .delete()
        .eq('id', deductionId);
    return true;
  } catch (e) {
    debugPrint('removeDeduction ERROR: $e');
    return false;
  }
}

/// Set/acknowledge that open reports will carry over after close.
Future<bool> setReportsCarryOver({
  required String contractId,
  required String terminationId,
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;
    await Supabase.instance.client
        .from('contract_termination')
        .update({'reports_carry_over_ack': true})
        .eq('id', terminationId);
    await _logContractEvent(
      contractId: contractId,
      actorId: actorId,
      eventType: 'reports_carry_over_set',
      payload: {},
    );
    return true;
  } catch (e) {
    debugPrint('setReportsCarryOver ERROR: $e');
    return false;
  }
}

/// Waive outstanding balance before closing.
Future<bool> waiveOutstandingBalance({
  required String contractId,
  required String terminationId,
  String? note,
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;
    await Supabase.instance.client
        .from('contract_termination')
        .update({
          'outstanding_balance_waived': true,
          'outstanding_balance_waive_note': ?note,
        })
        .eq('id', terminationId);
    await _logContractEvent(
      contractId: contractId,
      actorId: actorId,
      eventType: 'outstanding_balance_waived',
      payload: {'note': note ?? ''},
    );
    return true;
  } catch (e) {
    debugPrint('waiveOutstandingBalance ERROR: $e');
    return false;
  }
}

/// Close contract: flip status to closed, archive listing, set landlord_closed_at.
Future<bool> closeContract({
  required String contractId,
  required String terminationId,
  required String listingId,
}) async {
  try {
    final actorId = Supabase.instance.client.auth.currentUser?.id;
    if (actorId == null) return false;
    final now = DateTime.now().toIso8601String();
    await Future.wait([
      Supabase.instance.client
          .from('contract')
          .update({
            'status': 'closed',
            'actual_end_date': now,
            'updated_at': now,
          })
          .eq('id', contractId),
      Supabase.instance.client
          .from('contract_termination')
          .update({'landlord_closed_at': now})
          .eq('id', terminationId),
      Supabase.instance.client
          .from('listings')
          .update({'status': 'archived', 'updated_at': now})
          .eq('id', listingId),
    ]);
    await _logContractEvent(
      contractId: contractId,
      actorId: actorId,
      eventType: 'contract_closed',
      payload: {},
    );
    return true;
  } catch (e) {
    debugPrint('closeContract ERROR: $e');
    return false;
  }
}

/// Relist an archived listing (make it active again).
Future<bool> relistListing(String listingId) async {
  try {
    await Supabase.instance.client
        .from('listings')
        .update({
          'status': 'active',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', listingId);
    return true;
  } catch (e) {
    debugPrint('relistListing ERROR: $e');
    return false;
  }
}

/// Internal: write an audit event to contract_event.
Future<void> _logContractEvent({
  required String contractId,
  required String actorId,
  required String eventType,
  required Map<String, dynamic> payload,
}) async {
  try {
    await Supabase.instance.client.from('contract_event').insert({
      'contract_id': contractId,
      'actor_id': actorId,
      'event_type': eventType,
      'payload': payload,
    });
  } catch (e) {
    debugPrint('_logContractEvent ERROR: $e');
  }
}

/// Also update fetchActiveTenants to include post-paid statuses.
Future<List<Map<String, dynamic>>> fetchActiveTenantsAll() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await Supabase.instance.client
        .from('contract')
        .select(
          'id, status, listing_id, tenant_id, application_id, listing_type, '
          'landlord_signed_at, start_date, end_date, '
          'listings(id, title, landlord_id), '
          'application(first_name, last_name, email, phone_number)',
        )
        .eq('landlord_id', userId)
        .inFilter('status', _activeRentalStatuses)
        .order('landlord_signed_at', ascending: false);
    final contracts = (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final tenantIds = contracts
        .map((c) => c['tenant_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (tenantIds.isNotEmpty) {
      try {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', tenantIds);
        final byId = <String, Map<String, dynamic>>{
          for (final p in (profiles as List))
            (p as Map)['id'].toString(): Map<String, dynamic>.from(p),
        };
        for (final c in contracts) {
          final tid = c['tenant_id']?.toString();
          if (tid != null) c['tenant_profile'] = byId[tid] ?? {};
        }
      } catch (_) {}
    }

    final contractIds = contracts
        .map((c) => c['id']?.toString())
        .whereType<String>()
        .toList();
    if (contractIds.isNotEmpty) {
      try {
        final terminations = await Supabase.instance.client
            .from('contract_termination')
            .select(
              'id, contract_id, initiated_by, type, notice_date, effective_date, '
              'reason, security_deposit_amount, mutual_proposed_at, '
              'mutual_accepted_by_tenant_at, mutual_accepted_by_landlord_at, '
              'mutual_withdrawn_at, tenant_vacated_confirmed_at, landlord_closed_at',
            )
            .inFilter('contract_id', contractIds)
            .filter('mutual_withdrawn_at', 'is', null)
            .filter('landlord_closed_at', 'is', null)
            .order('notice_date', ascending: false);
        // Keep only the most recent open termination per contract.
        final byContractId = <String, Map<String, dynamic>>{};
        for (final t in (terminations as List)) {
          final row = Map<String, dynamic>.from(t as Map);
          final cid = row['contract_id']?.toString();
          if (cid == null) continue;
          byContractId.putIfAbsent(cid, () => row);
        }
        for (final c in contracts) {
          final cid = c['id']?.toString();
          if (cid != null && byContractId.containsKey(cid)) {
            c['termination'] = byContractId[cid];
          }
        }
      } catch (e) {
        debugPrint('fetchActiveTenantsAll termination enrich ERROR: $e');
      }
    }
    return contracts;
  } catch (e) {
    debugPrint('fetchActiveTenantsAll ERROR: $e');
    return [];
  }
}
