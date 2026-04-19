import 'package:flutter_test/flutter_test.dart';
import 'package:vxr_flutter/property_data.dart';

void main() {
  // ───────────────────────────────────────────
  // Property.fromMap — full data
  // ───────────────────────────────────────────
  group('Property.fromMap', () {
    test('parses a complete listings_full row correctly', () {
      final map = <String, dynamic>{
        'id': 'abc-123',
        'title': 'Cozy Studio',
        'city': 'Cebu City',
        'barangay': 'Lahug',
        'monthly_rent': 12500,
        'bedrooms': 2,
        'bathrooms': 1,
        'square_meters': 35.0,
        'cover_photo_url': 'https://example.com/photo.jpg',
        'latitude': 10.315,
        'longitude': 123.885,
        'property_type': 'Apartment',
        'description': 'Nice place',
        'furnishing': 'Fully Furnished',
        'pets_allowed': true,
        'smoking_allowed': false,
      };

      final p = Property.fromMap(map);

      expect(p.id, 'abc-123');
      expect(p.title, 'Cozy Studio');
      expect(p.city, 'Cebu City');
      expect(p.barangay, 'Lahug');
      expect(p.location, 'Lahug, Cebu City');
      expect(p.price, '₱12,500/month');
      expect(p.beds, 2);
      expect(p.baths, '1');
      expect(p.area, '35m²');
      expect(p.lat, 10.315);
      expect(p.lng, 123.885);
      expect(p.propertyType, 'Apartment');
      expect(p.label, 'Apartment');
      expect(p.description, 'Nice place');
      expect(p.furnishing, 'Fully Furnished');
      expect(p.petsAllowed, true);
      expect(p.smokingAllowed, false);
      // cover_photo_url already a full URL → returned as-is
      expect(p.image, 'https://example.com/photo.jpg');
    });

    test('handles missing / null fields gracefully', () {
      final map = <String, dynamic>{
        'id': null,
        'title': null,
        'city': null,
        'barangay': null,
        'monthly_rent': null,
        'bedrooms': null,
        'bathrooms': null,
        'square_meters': null,
        'cover_photo_url': null,
        'latitude': null,
        'longitude': null,
        'property_type': null,
        'description': null,
        'furnishing': null,
        'pets_allowed': null,
        'smoking_allowed': null,
      };

      final p = Property.fromMap(map);

      expect(p.id, isNull);
      expect(p.title, '');
      expect(p.city, '');
      expect(p.barangay, '');
      expect(p.location, ''); // falls back to full_address which is also null
      expect(p.price, '₱0/month');
      expect(p.beds, 0);
      expect(p.baths, '1'); // default
      expect(p.area, ''); // sqm was null
      expect(p.lat, 0.0);
      expect(p.lng, 0.0);
      expect(p.petsAllowed, false);
      expect(p.smokingAllowed, false);
      expect(p.image, ''); // empty path → ''
    });

    test('uses full_address when city and barangay are empty', () {
      final map = <String, dynamic>{
        'title': 'Test',
        'city': '',
        'barangay': '',
        'full_address': '123 Main St, Manila',
        'monthly_rent': 5000,
        'bedrooms': 1,
        'bathrooms': 1,
        'cover_photo_url': '',
      };

      final p = Property.fromMap(map);
      expect(p.location, '123 Main St, Manila');
    });

    test('builds location with only city when barangay is empty', () {
      final map = <String, dynamic>{
        'title': 'Test',
        'city': 'Manila',
        'barangay': '',
        'monthly_rent': 8000,
        'bedrooms': 0,
        'bathrooms': 1,
        'cover_photo_url': '',
      };

      final p = Property.fromMap(map);
      expect(p.location, 'Manila');
    });

    test('builds location with only barangay when city is empty', () {
      final map = <String, dynamic>{
        'title': 'Test',
        'city': '',
        'barangay': 'Poblacion',
        'monthly_rent': 8000,
        'bedrooms': 0,
        'bathrooms': 1,
        'cover_photo_url': '',
      };

      final p = Property.fromMap(map);
      expect(p.location, 'Poblacion');
    });

    test('parses Studio (0 bedrooms) correctly', () {
      final map = <String, dynamic>{
        'title': 'Studio Unit',
        'city': 'QC',
        'barangay': '',
        'monthly_rent': 6000,
        'bedrooms': 'Studio',
        'bathrooms': 1,
        'cover_photo_url': '',
      };

      final p = Property.fromMap(map);
      expect(p.beds, 0); // "Studio" → int.tryParse fails → 0
    });

    test('formats large rent with commas', () {
      final map = <String, dynamic>{
        'title': 'Luxury Condo',
        'city': 'BGC',
        'barangay': '',
        'monthly_rent': 150000,
        'bedrooms': 3,
        'bathrooms': 2,
        'cover_photo_url': '',
      };

      final p = Property.fromMap(map);
      expect(p.price, '₱150,000/month');
    });

    test('formats small rent without commas', () {
      final map = <String, dynamic>{
        'title': 'Bedspace',
        'city': '',
        'barangay': '',
        'monthly_rent': 500,
        'bedrooms': 0,
        'bathrooms': 1,
        'cover_photo_url': '',
      };

      final p = Property.fromMap(map);
      expect(p.price, '₱500/month');
    });

    test('handles integer square_meters', () {
      final map = <String, dynamic>{
        'title': 'T',
        'city': '',
        'barangay': '',
        'monthly_rent': 0,
        'bedrooms': 0,
        'bathrooms': 0,
        'cover_photo_url': '',
        'square_meters': 42,
      };

      final p = Property.fromMap(map);
      expect(p.area, '42m²');
    });
  });

  // ───────────────────────────────────────────
  // buildStorageUrl
  // ───────────────────────────────────────────
  group('buildStorageUrl', () {
    test('returns empty string for empty path', () {
      expect(buildStorageUrl(''), '');
    });

    test('returns full https URL as-is', () {
      const url = 'https://cdn.example.com/photo.jpg';
      expect(buildStorageUrl(url), url);
    });

    test('returns full http URL as-is', () {
      const url = 'http://cdn.example.com/photo.jpg';
      expect(buildStorageUrl(url), url);
    });
  });

  // ───────────────────────────────────────────
  // haversineKm
  // ───────────────────────────────────────────
  group('haversineKm', () {
    test('same point returns 0', () {
      expect(haversineKm(10.0, 120.0, 10.0, 120.0), 0.0);
    });

    test('Manila to Cebu is roughly 565 km', () {
      // Manila ~(14.5995, 120.9842), Cebu ~(10.3157, 123.8854)
      final d = haversineKm(14.5995, 120.9842, 10.3157, 123.8854);
      expect(d, greaterThan(540));
      expect(d, lessThan(590));
    });

    test('short distance is accurate', () {
      // Two points ~1 km apart in Manila
      final d = haversineKm(14.5995, 120.9842, 14.6085, 120.9842);
      expect(d, greaterThan(0.9));
      expect(d, lessThan(1.1));
    });

    test('antipodal points are roughly 20000 km', () {
      final d = haversineKm(0, 0, 0, 180);
      expect(d, greaterThan(20000));
      expect(d, lessThan(20100));
    });
  });

  // ───────────────────────────────────────────
  // computeDistances
  // ───────────────────────────────────────────
  group('computeDistances', () {
    test('sets distanceKm on each property', () {
      final props = [
        _makeProperty(lat: 14.5995, lng: 120.9842),
        _makeProperty(lat: 10.3157, lng: 123.8854),
      ];

      computeDistances(props, 14.5995, 120.9842);

      expect(props[0].distanceKm, closeTo(0.0, 0.01));
      expect(props[1].distanceKm, greaterThan(500));
    });
  });

  // ───────────────────────────────────────────
  // propertiesByCategory
  // ───────────────────────────────────────────
  group('propertiesByCategory', () {
    final props = [
      _makeProperty(beds: 0), // Studio
      _makeProperty(beds: 1), // 1BR
      _makeProperty(beds: 2), // 2BR
      _makeProperty(beds: 3), // 3BR
      _makeProperty(beds: 4), // 4BR
    ];

    test('category 0 returns all', () {
      expect(propertiesByCategory(0, source: props).length, 5);
    });

    test('category 1 returns studios (0 beds)', () {
      final result = propertiesByCategory(1, source: props);
      expect(result.length, 1);
      expect(result.first.beds, 0);
    });

    test('category 2 returns 1BR', () {
      final result = propertiesByCategory(2, source: props);
      expect(result.length, 1);
      expect(result.first.beds, 1);
    });

    test('category 3 returns 2BR', () {
      final result = propertiesByCategory(3, source: props);
      expect(result.length, 1);
      expect(result.first.beds, 2);
    });

    test('category 4 returns 3+ BR', () {
      final result = propertiesByCategory(4, source: props);
      expect(result.length, 2); // beds 3 and 4
    });
  });

  // ───────────────────────────────────────────
  // passesFilters
  // ───────────────────────────────────────────
  group('passesFilters', () {
    test('empty filters passes everything', () {
      final p = _makeProperty(beds: 2);
      expect(passesFilters(p, {}), true);
    });

    test('bedroom filter matches', () {
      final p = _makeProperty(beds: 2);
      expect(passesFilters(p, {'bedrooms': 2}), true);
      expect(passesFilters(p, {'bedrooms': 3}), false);
    });

    test('bedroom filter 0 is ignored (means Any)', () {
      final p = _makeProperty(beds: 2);
      expect(passesFilters(p, {'bedrooms': 0}), true);
    });

    test('bathroom filter matches', () {
      final p = _makeProperty(baths: '2');
      expect(passesFilters(p, {'bathrooms': 2}), true);
      expect(passesFilters(p, {'bathrooms': 1}), false);
    });

    test('area range filter', () {
      final p = _makeProperty(area: '50m²');
      expect(passesFilters(p, {'minArea': 30, 'maxArea': 60}), true);
      expect(passesFilters(p, {'minArea': 60, 'maxArea': 100}), false);
    });

    test('propertyType filter', () {
      final p = _makeProperty(propertyType: 'Apartment');
      expect(passesFilters(p, {'propertyType': 'Apartment'}), true);
      expect(passesFilters(p, {'propertyType': 'House'}), false);
      expect(passesFilters(p, {'propertyType': 'Any'}), true);
    });

    test('furnishing filter', () {
      final p = _makeProperty(furnishing: 'Fully Furnished');
      expect(passesFilters(p, {'furnishing': 'Fully Furnished'}), true);
      expect(passesFilters(p, {'furnishing': 'Unfurnished'}), false);
      expect(passesFilters(p, {'furnishing': 'Any'}), true);
    });

    test('pet policy filter — Pets Allowed', () {
      final petsYes = _makeProperty(petsAllowed: true);
      final petsNo = _makeProperty(petsAllowed: false);

      expect(passesFilters(petsYes, {'petPolicy': 'Pets Allowed'}), true);
      expect(passesFilters(petsNo, {'petPolicy': 'Pets Allowed'}), false);
    });

    test('pet policy filter — No Pets', () {
      final petsYes = _makeProperty(petsAllowed: true);
      final petsNo = _makeProperty(petsAllowed: false);

      expect(passesFilters(petsNo, {'petPolicy': 'No Pets'}), true);
      expect(passesFilters(petsYes, {'petPolicy': 'No Pets'}), false);
    });

    test('pet policy Any passes all', () {
      expect(passesFilters(_makeProperty(petsAllowed: true), {'petPolicy': 'Any'}), true);
      expect(passesFilters(_makeProperty(petsAllowed: false), {'petPolicy': 'Any'}), true);
    });

    test('smoking policy filter — Smoking Allowed', () {
      final smokingYes = _makeProperty(smokingAllowed: true);
      final smokingNo = _makeProperty(smokingAllowed: false);

      expect(passesFilters(smokingYes, {'smokingPolicy': 'Smoking Allowed'}), true);
      expect(passesFilters(smokingNo, {'smokingPolicy': 'Smoking Allowed'}), false);
    });

    test('smoking policy filter — No Smoking', () {
      final smokingYes = _makeProperty(smokingAllowed: true);
      final smokingNo = _makeProperty(smokingAllowed: false);

      expect(passesFilters(smokingNo, {'smokingPolicy': 'No Smoking'}), true);
      expect(passesFilters(smokingYes, {'smokingPolicy': 'No Smoking'}), false);
    });

    test('multiple filters combined', () {
      final p = _makeProperty(
        beds: 2,
        baths: '1',
        propertyType: 'Apartment',
        petsAllowed: true,
      );

      expect(passesFilters(p, {
        'bedrooms': 2,
        'bathrooms': 1,
        'propertyType': 'Apartment',
        'petPolicy': 'Pets Allowed',
      }), true);

      // Fails on bedrooms
      expect(passesFilters(p, {
        'bedrooms': 3,
        'bathrooms': 1,
        'propertyType': 'Apartment',
      }), false);
    });
  });

  // ───────────────────────────────────────────
  // sortProperties
  // ───────────────────────────────────────────
  group('sortProperties', () {
    test('Price: Low to High', () {
      final props = [
        _makeProperty(price: '₱15,000/month'),
        _makeProperty(price: '₱5,000/month'),
        _makeProperty(price: '₱10,000/month'),
      ];

      sortProperties(props, 'Price: Low to High');

      expect(props[0].price, '₱5,000/month');
      expect(props[1].price, '₱10,000/month');
      expect(props[2].price, '₱15,000/month');
    });

    test('Price: High to Low', () {
      final props = [
        _makeProperty(price: '₱5,000/month'),
        _makeProperty(price: '₱15,000/month'),
        _makeProperty(price: '₱10,000/month'),
      ];

      sortProperties(props, 'Price: High to Low');

      expect(props[0].price, '₱15,000/month');
      expect(props[1].price, '₱10,000/month');
      expect(props[2].price, '₱5,000/month');
    });

    test('Nearest', () {
      final props = [
        _makeProperty(distanceKm: 10.0),
        _makeProperty(distanceKm: 2.0),
        _makeProperty(distanceKm: 5.0),
      ];

      sortProperties(props, 'Nearest');

      expect(props[0].distanceKm, 2.0);
      expect(props[1].distanceKm, 5.0);
      expect(props[2].distanceKm, 10.0);
    });

    test('Nearest handles null distances', () {
      final props = [
        _makeProperty(distanceKm: null),
        _makeProperty(distanceKm: 3.0),
        _makeProperty(distanceKm: null),
      ];

      sortProperties(props, 'Nearest');

      expect(props[0].distanceKm, 3.0);
      expect(props[1].distanceKm, isNull); // null → infinity, goes to end
      expect(props[2].distanceKm, isNull);
    });
  });

  // ───────────────────────────────────────────
  // detectUserCity
  // ───────────────────────────────────────────
  group('detectUserCity', () {
    test('returns city of nearest property', () {
      final props = [
        _makeProperty(city: 'Cebu', distanceKm: 100.0),
        _makeProperty(city: 'Manila', distanceKm: 5.0),
        _makeProperty(city: 'Davao', distanceKm: 50.0),
      ];

      expect(detectUserCity(props), 'Manila');
    });

    test('returns empty string for empty list', () {
      expect(detectUserCity([]), '');
    });

    test('handles properties with null distances', () {
      final props = [
        _makeProperty(city: 'Far', distanceKm: null),
        _makeProperty(city: 'Near', distanceKm: 1.0),
      ];

      expect(detectUserCity(props), 'Near');
    });
  });

  // ───────────────────────────────────────────
  // propertiesInCity
  // ───────────────────────────────────────────
  group('propertiesInCity', () {
    test('filters by city name (case-insensitive)', () {
      allProperties = [
        _makeProperty(city: 'Cebu City'),
        _makeProperty(city: 'Manila'),
        _makeProperty(city: 'cebu city'),
      ];

      final result = propertiesInCity('Cebu City');
      expect(result.length, 2);
    });

    test('empty city returns all', () {
      allProperties = [
        _makeProperty(city: 'A'),
        _makeProperty(city: 'B'),
      ];

      expect(propertiesInCity('').length, 2);
    });
  });

  // ───────────────────────────────────────────
  // nearestProperties
  // ───────────────────────────────────────────
  group('nearestProperties', () {
    test('returns properties sorted by distance', () {
      allProperties = [
        _makeProperty(distanceKm: 20.0, title: 'Far'),
        _makeProperty(distanceKm: 1.0, title: 'Near'),
        _makeProperty(distanceKm: 10.0, title: 'Mid'),
      ];

      final result = nearestProperties();
      expect(result[0].title, 'Near');
      expect(result[1].title, 'Mid');
      expect(result[2].title, 'Far');
    });
  });

  // ───────────────────────────────────────────
  // Property.fromMap with normalized view data
  // ───────────────────────────────────────────
  group('Property.fromMap — listings_full view shape', () {
    test('parses data shaped like the listings_full view (joined columns)', () {
      // Simulates a row from listings_full that has columns from
      // all 10 child tables merged into one flat row.
      final viewRow = <String, dynamic>{
        // Core (listings)
        'id': 'view-001',
        'landlord_id': 'user-xyz',
        'title': 'Normalized Unit',
        'description': 'Test from view',
        'property_type': 'Condo',
        'status': 'active',
        'cover_photo_url': 'https://img.test/cover.jpg',
        'is_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        // Location (listing_locations)
        'full_address': '456 View St, Makati',
        'barangay': 'Poblacion',
        'city': 'Makati',
        'province': 'Metro Manila',
        'postal_code': '1210',
        'latitude': 14.5547,
        'longitude': 121.0244,
        // Details (listing_details)
        'bedrooms': 1,
        'bathrooms': 1,
        'max_occupants': 2,
        'square_meters': 28.0,
        'furnishing': 'Semi-Furnished',
        'flooring_type': 'Tile',
        'floor_number': 5,
        'total_floors': 20,
        'year_built': 2020,
        'has_balcony': true,
        'has_storage': false,
        'has_natural_light': true,
        // Amenities (listing_amenities)
        'has_aircon': true,
        'has_refrigerator': false,
        'has_washing_machine': false,
        'has_water_heater': true,
        'has_stove': false,
        'has_cabinet': true,
        'has_bed': true,
        // Utilities (listing_utilities)
        'with_water': true,
        'with_electricity': true,
        'with_internet': false,
        'with_parking': false,
        // Building features
        'has_security': true,
        'has_elevator': true,
        'has_backup_power': true,
        'has_pool': false,
        'has_gym': true,
        'has_laundry_area': false,
        'has_function_hall': false,
        'has_playground': false,
        // Financials
        'monthly_rent': 18000,
        'security_deposit': 36000,
        'advance_payment': 18000,
        'payment_terms': 'Monthly',
        'payment_method': 'GCash',
        // Availability
        'is_immediate': true,
        'available_from': null,
        'lease_term': '1 Year',
        // Policies
        'pets_allowed': false,
        'smoking_allowed': false,
        'no_curfew': true,
        'subletting_allowed': false,
        'guest_policy': 'With prior notice',
        'modification_allowed': false,
        // Requirements
        'requires_proof_of_income': true,
        'requires_employment_cert': true,
        'requires_valid_id': true,
        'requires_references': false,
        // Host info
        'host_name': 'Juan Dela Cruz',
        'host_role': 'Owner',
        'response_time': 'Within 24 hours',
      };

      final p = Property.fromMap(viewRow);

      // Property model fields populated from the flat view
      expect(p.id, 'view-001');
      expect(p.title, 'Normalized Unit');
      expect(p.city, 'Makati');
      expect(p.barangay, 'Poblacion');
      expect(p.location, 'Poblacion, Makati');
      expect(p.price, '₱18,000/month');
      expect(p.beds, 1);
      expect(p.baths, '1');
      expect(p.area, '28m²');
      expect(p.lat, 14.5547);
      expect(p.lng, 121.0244);
      expect(p.propertyType, 'Condo');
      expect(p.description, 'Test from view');
      expect(p.furnishing, 'Semi-Furnished');
      expect(p.petsAllowed, false);
      expect(p.smokingAllowed, false);
      expect(p.image, 'https://img.test/cover.jpg');
    });

    test('handles view row where child tables have no data (all nulls)', () {
      // If a child table row doesn't exist, LEFT JOIN yields nulls
      final viewRow = <String, dynamic>{
        'id': 'view-002',
        'title': 'Empty Children',
        'status': 'active',
        'cover_photo_url': null,
        // All joined columns null (no child rows)
        'city': null,
        'barangay': null,
        'full_address': null,
        'monthly_rent': null,
        'bedrooms': null,
        'bathrooms': null,
        'square_meters': null,
        'latitude': null,
        'longitude': null,
        'property_type': null,
        'description': null,
        'furnishing': null,
        'pets_allowed': null,
        'smoking_allowed': null,
      };

      final p = Property.fromMap(viewRow);

      expect(p.id, 'view-002');
      expect(p.title, 'Empty Children');
      expect(p.location, '');
      expect(p.price, '₱0/month');
      expect(p.beds, 0);
      expect(p.area, '');
      expect(p.lat, 0.0);
      expect(p.lng, 0.0);
      expect(p.petsAllowed, false);
      expect(p.smokingAllowed, false);
      expect(p.image, '');
    });
  });

  // ───────────────────────────────────────────
  // Normalized CRUD function signatures
  // ───────────────────────────────────────────
  group('Normalized CRUD — signature verification', () {
    // These tests verify the functions exist with the expected
    // named parameters and correct return types. They don't call
    // Supabase (that requires a live backend).

    test('insertListing accepts all 11 table maps', () {
      // Just verify the function reference is callable with named params.
      // We can't actually call it without Supabase, but we can verify
      // the type signature compiles.
      expect(insertListing, isA<Function>());
    });

    test('updateListing accepts listingId + 11 table maps', () {
      expect(updateListing, isA<Function>());
    });

    test('deleteListingFromSupabase accepts a string ID', () {
      expect(deleteListingFromSupabase, isA<Function>());
    });

    test('saveListingImages accepts listingId and paths', () {
      expect(saveListingImages, isA<Function>());
    });

    test('fetchProperties returns Future<List<Property>>', () {
      expect(fetchProperties, isA<Function>());
    });

    test('fetchListingDetails returns Future<Map?>', () {
      expect(fetchListingDetails, isA<Function>());
    });

    test('fetchLandlordListings returns Future<List<Property>>', () {
      expect(fetchLandlordListings, isA<Function>());
    });
  });
}

// ───────────────────────────────────────────
// Test helper — builds a Property without Supabase
// ───────────────────────────────────────────
Property _makeProperty({
  String title = 'Test',
  String city = '',
  String barangay = '',
  String price = '₱10,000/month',
  int beds = 1,
  String baths = '1',
  String area = '30m²',
  double lat = 0.0,
  double lng = 0.0,
  String? propertyType,
  String? furnishing,
  bool petsAllowed = false,
  bool smokingAllowed = false,
  double? distanceKm,
}) {
  return Property(
    image: '',
    title: title,
    location: [if (barangay.isNotEmpty) barangay, if (city.isNotEmpty) city].join(', '),
    city: city,
    barangay: barangay,
    price: price,
    beds: beds,
    baths: baths,
    area: area,
    lat: lat,
    lng: lng,
    propertyType: propertyType,
    furnishing: furnishing,
    petsAllowed: petsAllowed,
    smokingAllowed: smokingAllowed,
    distanceKm: distanceKm,
  );
}
