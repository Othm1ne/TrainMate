class EventItem {
  final String id;
  final String title;
  final String category; // one of your sports
  final DateTime dateTime;
  final String place;
  final double distanceKm;
  final String cover; // URL or local path
  final int attendees;
  final List<String> attendeePhotos;
  final String? description;

  const EventItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.place,
    required this.distanceKm,
    required this.cover,
    required this.attendees,
    required this.attendeePhotos,
    this.description,
  });
}
