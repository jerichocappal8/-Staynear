class Property {
  final String id;
  final String name;
  final double price;
  final String city;
  final double rating;

  Property({
    required this.id,
    required this.name,
    required this.price,
    required this.city,
    required this.rating,
  });

  factory Property.fromMap(String id, Map<String, dynamic> data) {
    return Property(
      id: id,
      name: data['name'] ?? '',
      // Current schema writes minPrice; old data may use price.
      price: ((data['minPrice'] ?? data['price'] ?? 0) as num).toDouble(),
      // Current schema writes city; old data may store it in address or location.
      city: (data['city'] as String? ?? data['address'] as String? ?? data['location'] as String? ?? ''),
      rating: ((data['rating'] ?? 0) as num).toDouble(),
    );
  }
}