class Testimonial {
  final String name;
  final double rating;
  final String comment;
  final String photoUrl;

  const Testimonial({
    required this.name,
    required this.rating,
    required this.comment,
    required this.photoUrl,
  });

  factory Testimonial.fromMap(Map<String, dynamic> map) {
    return Testimonial(
      name: map['name'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
    );
  }
}