class Cat {
  final String name, code, department;
  final List<String> subs;
  const Cat(this.name, this.code, this.department, this.subs);
}

class AppConstants {
  static const categories = <Cat>[
    Cat('Illegal Parking', 'PARKING', 'Parking',
        ['footpath parking', 'no-parking zone', 'double parking', 'blocking gate/driveway', 'other']),
    Cat('Waste', 'WASTE', 'Waste Management',
        ['garbage pile', 'overflowing bin', 'burning waste', 'dead animal']),
    Cat('Street Light', 'STREETLIGHT', 'Streetlight',
        ['not working', 'flickering', 'on during day', 'damaged pole', 'exposed wire']),
    Cat('Road', 'ROAD', 'Road',
        ['pothole', 'crack', 'broken road', 'missing road sign', 'blocked road']),
    Cat('Water & Drainage', 'WATER', 'Water & Drainage',
        ['leakage', 'blocked drain', 'no supply', 'sewage overflow']),
    Cat('Illegal Construction', 'CONSTRUCTION', 'Illegal Construction',
        ['no permit', 'encroachment', 'unsafe structure', 'other']),
  ];
  static Cat byName(String n) => categories.firstWhere((c) => c.name == n);
  static const departments = ['Parking', 'Waste Management', 'Streetlight', 'Road', 'Water & Drainage', 'Illegal Construction'];
  static const statuses = ['Submitted', 'Verified', 'Assigned', 'In Progress', 'Resolved'];
  static const allStatuses = [...statuses, 'Rejected'];
  static final wards = List.generate(32, (i) => i + 1);
  // Kathmandu Metropolitan City approximate bounding box (replace with real polygon).
  static const bounds = {'minLat': 27.64, 'maxLat': 27.78, 'minLng': 85.26, 'maxLng': 85.42};
  static const roles = ['citizen', 'field_worker', 'department_admin', 'super_admin'];
}
