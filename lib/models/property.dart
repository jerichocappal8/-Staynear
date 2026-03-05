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
      name: data['name'],
      price: (data['price'] as num).toDouble(),
      city: data['city'],
      rating: (data['rating'] as num).toDouble(),
    );
  }
}