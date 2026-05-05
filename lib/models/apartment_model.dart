import 'package:cloud_firestore/cloud_firestore.dart';
import 'rental_terms.dart';
import 'nearby_facility.dart';
import 'testimonial.dart';

class ApartmentModel {
  final String id;
  final String name;
  final String address;
  final String ownerId;
  final String category;
  final String description;

  final double rating;
  final int reviewCount;
  final double minPrice;

  final double lat;
  final double lng;

  final List<String> images;
  final String coverImageUrl;

  final List<String> facilities;
  final List<String> houseRules;

  final RentalTerms rentalTerms;
  final List<NearbyFacility> nearbyFacilities;
  final List<Testimonial> testimonials;

  ApartmentModel({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerId,
    required this.category,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.minPrice,
    required this.lat,
    required this.lng,
    required this.images,
    required this.coverImageUrl,
    required this.facilities,
    required this.houseRules,
    required this.rentalTerms,
    required this.nearbyFacilities,
    required this.testimonials,
  });

  factory ApartmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final GeoPoint? geo = data['coordinates'];

    // Images: prefer imageUrls (current schema), fall back to images (old schema).
    final imageList = List<String>.from(data['imageUrls'] ?? data['images'] ?? []);

    // Cover: use stored coverImageUrl when present, otherwise first image.
    final cover = (data['coverImageUrl'] as String? ?? '').isNotEmpty
        ? data['coverImageUrl'] as String
        : imageList.isNotEmpty ? imageList.first : '';

    return ApartmentModel(
      id: doc.id,
      name: data['name'] ?? '',
      // Address: current schema writes 'address'; old data may use 'location'.
      address: (data['address'] as String? ?? data['city'] as String? ?? data['location'] as String? ?? ''),
      ownerId: data['ownerId'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      // Price: current schema writes 'minPrice'; old data may use 'price'.
      minPrice: ((data['minPrice'] ?? data['price'] ?? 0) as num).toDouble(),

      lat: geo?.latitude ?? 0,
      lng: geo?.longitude ?? 0,

      images: imageList,
      coverImageUrl: cover,

      facilities: List<String>.from(data['amenities'] ?? []),
      houseRules: List<String>.from(data['houseRules'] ?? []),

      rentalTerms: RentalTerms.fromMap(data['rentalTerms'] ?? {}),

      nearbyFacilities: (data['nearbyFacilities'] ?? [])
          .map<NearbyFacility>((e) => NearbyFacility.fromMap(e))
          .toList(),

testimonials: (data['testimonials'] ?? [])
    .map<Testimonial>((e) => Testimonial(
  name: e['name'] ?? '',
  photoUrl: e['photoUrl'] ?? '',
  userId: e['userId'] ?? '',
  rating: ((e['rating'] ?? 0) as num).toDouble(),
  comment: e['comment'] ?? '',
))
    .toList(),
    );
  }
}