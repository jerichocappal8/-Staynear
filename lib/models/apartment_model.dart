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

    return ApartmentModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      ownerId: data['ownerId'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      minPrice: (data['minPrice'] ?? 0).toDouble(),

      lat: geo?.latitude ?? 0,
      lng: geo?.longitude ?? 0,

      images: List<String>.from(data['imageUrls'] ?? []),
      coverImageUrl: data['coverImageUrl'] ?? '',

      facilities: List<String>.from(data['amenities'] ?? []),
      houseRules: List<String>.from(data['houseRules'] ?? []),

      rentalTerms: RentalTerms.fromMap(data['rentalTerms'] ?? {}),

      nearbyFacilities: (data['nearbyFacilities'] ?? [])
          .map<NearbyFacility>((e) => NearbyFacility.fromMap(e))
          .toList(),

      testimonials: (data['testimonials'] ?? [])
          .map<Testimonial>((e) => Testimonial.fromMap(e))
          .toList(),
    );
  }
}