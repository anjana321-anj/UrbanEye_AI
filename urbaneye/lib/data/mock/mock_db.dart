import 'dart:async';
import 'dart:math' as math;

import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';

/// In-memory "server database" seeded with realistic Kathmandu data.
/// Shared by every mock repository so changes made in the admin console
/// are immediately visible in the citizen app (and vice versa).
class MockDb {
  MockDb._() {
    _seed();
  }
  static final MockDb instance = MockDb._();

  final _rand = math.Random(42);
  final changes = StreamController<String>.broadcast();

  static const municipality = Municipality(
    id: 'ktm-metro',
    name: 'Kathmandu Metropolitan City',
    center: GeoPoint(27.7040, 85.3200),
    emergencyNumbers: 'Police 100 · Fire 101 · Ambulance 102',
  );

  /// Default device position used when GPS is unavailable (Putalisadak).
  static const defaultUserPoint = GeoPoint(27.7032, 85.3221);

  static const areas = <String, GeoPoint>{
    'New Road': GeoPoint(27.7041, 85.3076),
    'Thamel': GeoPoint(27.7154, 85.3123),
    'Baneshwor': GeoPoint(27.6915, 85.3420),
    'Lazimpat': GeoPoint(27.7210, 85.3200),
    'Koteshwor': GeoPoint(27.6788, 85.3494),
    'Patan Durbar Square': GeoPoint(27.6727, 85.3253),
    'Kalanki': GeoPoint(27.6933, 85.2817),
    'Chabahil': GeoPoint(27.7173, 85.3466),
    'Boudha': GeoPoint(27.7215, 85.3620),
    'Maharajgunj': GeoPoint(27.7369, 85.3304),
    'Kupondole': GeoPoint(27.6855, 85.3166),
    'Tripureshwor': GeoPoint(27.6939, 85.3142),
    'Durbarmarg': GeoPoint(27.7120, 85.3178),
    'Jawalakhel': GeoPoint(27.6726, 85.3140),
    'Sundhara': GeoPoint(27.7005, 85.3123),
    'Balaju': GeoPoint(27.7330, 85.3036),
    'Gongabu': GeoPoint(27.7350, 85.3140),
    'Putalisadak': GeoPoint(27.7039, 85.3221),
    'Naxal': GeoPoint(27.7135, 85.3270),
    'Teku': GeoPoint(27.6960, 85.3050),
  };

  static const streets = <String, String>{
    'New Road': 'Khichapokhari Marg',
    'Thamel': 'Chaksibari Marg',
    'Baneshwor': 'Madan Bhandari Path',
    'Lazimpat': 'Lazimpat Road',
    'Koteshwor': 'Araniko Highway',
    'Patan Durbar Square': 'Mangal Bazaar',
    'Kalanki': 'Ring Road, Kalanki Chowk',
    'Chabahil': 'Chabahil–Gaushala Road',
    'Boudha': 'Boudha Stupa Road',
    'Maharajgunj': 'Maharajgunj Road',
    'Kupondole': 'Kupondole Height',
    'Tripureshwor': 'Tripureshwor Marg',
    'Durbarmarg': 'Durbar Marg',
    'Jawalakhel': 'Jawalakhel Chowk',
    'Sundhara': 'Sundhara Marg',
    'Balaju': 'Balaju Bypass',
    'Gongabu': 'Gongabu Bus Park Road',
    'Putalisadak': 'Putalisadak Marg',
    'Naxal': 'Naxal Bhagwati Marg',
    'Teku': 'Teku Road',
  };

  final users = <String, AppUser>{};
  final reports = <String, Report>{};
  final notifications = <AppNotification>[];
  final audit = <AuditLog>[];
  final teams = <Team>[];
  final vehicles = <Vehicle>[];
  final pickups = <WastePickup>[];
  final servicePoints = <ServicePoint>[];
  final savedLocations = <String, List<SavedLocation>>{};

  int _ticket = 10285;
  int _id = 1;
  String nextTicket() => 'UE-${_ticket++}';
  String nextId(String prefix) => '$prefix-${_id++}';

  void emit(String what) => changes.add(what);

  PlaceLocation placeFor(String area, {double jitter = 0.0025}) {
    final c = areas[area]!;
    final p = GeoPoint(c.lat + (_rand.nextDouble() - 0.5) * jitter, c.lng + (_rand.nextDouble() - 0.5) * jitter);
    return PlaceLocation(point: p, address: '${streets[area]}, $area, Kathmandu', area: area);
  }

  // -------------------------------------------------------------------------
  // Seed
  // -------------------------------------------------------------------------

  void _seed() {
    final now = DateTime.now();

    users['u-alex'] = AppUser(
      id: 'u-alex',
      name: 'Alex Shrestha',
      email: 'alex.shrestha@example.com',
      phone: '+9779841234567',
      city: 'Kathmandu',
      role: UserRole.citizen,
      municipalityId: municipality.id,
      joinedAt: now.subtract(const Duration(days: 210)),
    );
    users['u-admin'] = AppUser(
      id: 'u-admin',
      name: 'Sita Maharjan',
      email: 'sita.maharjan@kathmandu.gov.np',
      phone: '+9779801000001',
      city: 'Kathmandu',
      role: UserRole.municipalAdmin,
      municipalityId: municipality.id,
      joinedAt: now.subtract(const Duration(days: 900)),
    );
    final citizenNames = [
      'Pratik Adhikari', 'Anisha Gurung', 'Ramesh Thapa', 'Sujata Karki', 'Bikash Tamang',
      'Nisha Rai', 'Suman Bhandari', 'Kabita Lama', 'Rohan KC', 'Asmita Poudel',
    ];
    for (var i = 0; i < citizenNames.length; i++) {
      users['u-c$i'] = AppUser(
        id: 'u-c$i',
        name: citizenNames[i],
        email: '${citizenNames[i].split(' ').first.toLowerCase()}@example.com',
        phone: '+97798${(10000000 + i * 734521) % 99999999}',
        city: 'Kathmandu',
        role: UserRole.citizen,
        municipalityId: municipality.id,
        joinedAt: now.subtract(Duration(days: 30 + i * 17)),
      );
    }
    final staff = [
      ('Hari Prasad Joshi', UserRole.operator),
      ('Manisha Shakya', UserRole.supervisor),
      ('Dipak Basnet', UserRole.teamMember),
      ('Ritu Malla', UserRole.systemAdmin),
    ];
    for (var i = 0; i < staff.length; i++) {
      users['u-s$i'] = AppUser(
        id: 'u-s$i',
        name: staff[i].$1,
        email: '${staff[i].$1.split(' ').first.toLowerCase()}@kathmandu.gov.np',
        phone: '+97798010000${i + 2}',
        city: 'Kathmandu',
        role: staff[i].$2,
        municipalityId: municipality.id,
        joinedAt: now.subtract(Duration(days: 400 + i * 50)),
      );
    }

    _seedTeams();
    _seedPoints();
    _seedReports(now);
    _seedAlex(now);
    _seedPickups(now);
    _seedNotifications(now);

    savedLocations['u-alex'] = [
      SavedLocation(id: 'sl-1', label: 'Home', location: placeFor('Baneshwor', jitter: 0)),
      SavedLocation(id: 'sl-2', label: 'Work', location: placeFor('Durbarmarg', jitter: 0)),
    ];
  }

  void _seedTeams() {
    TeamMember m(String id, String n, String r, [bool on = true]) => TeamMember(id: id, name: n, role: r, onDuty: on);
    teams.addAll([
      Team(
        id: 'team-waste',
        name: 'Waste Collection Team',
        primaryCategory: ReportCategory.waste,
        members: [m('m1', 'Ram Bahadur Shrestha', 'Team Lead'), m('m2', 'Gita Tamang', 'Driver'), m('m3', 'Shyam Rai', 'Collector'), m('m4', 'Kumar Magar', 'Collector', false)],
        status: TeamStatus.busy,
        location: areas['Teku']!,
        locationLabel: 'Teku Transfer Station',
        activeTasks: 9,
        completedTasks: 412,
        capacity: 12,
      ),
      Team(
        id: 'team-road',
        name: 'Road Maintenance Team',
        primaryCategory: ReportCategory.road,
        members: [m('m5', 'Dipak Basnet', 'Engineer'), m('m6', 'Bishnu Khadka', 'Supervisor'), m('m7', 'Arjun Thapa', 'Technician'), m('m8', 'Laxmi Oli', 'Technician'), m('m9', 'Prem Gurung', 'Operator')],
        status: TeamStatus.busy,
        location: areas['Baneshwor']!,
        locationLabel: 'Baneshwor Depot',
        activeTasks: 11,
        completedTasks: 288,
        capacity: 12,
      ),
      Team(
        id: 'team-water',
        name: 'Water Department',
        primaryCategory: ReportCategory.water,
        members: [m('m10', 'Sarita Bista', 'Engineer'), m('m11', 'Nabin Karki', 'Plumber'), m('m12', 'Dinesh Lama', 'Plumber')],
        status: TeamStatus.available,
        location: areas['Tripureshwor']!,
        locationLabel: 'KUKL Tripureshwor',
        activeTasks: 4,
        completedTasks: 196,
        capacity: 8,
      ),
      Team(
        id: 'team-electric',
        name: 'Electrical Team',
        primaryCategory: ReportCategory.streetlight,
        members: [m('m13', 'Sanjay Maharjan', 'Electrician'), m('m14', 'Pooja Shahi', 'Electrician'), m('m15', 'Ravi Pandey', 'Helper')],
        status: TeamStatus.available,
        location: areas['Naxal']!,
        locationLabel: 'Naxal Workshop',
        activeTasks: 3,
        completedTasks: 157,
        capacity: 8,
      ),
      Team(
        id: 'team-parking',
        name: 'Parking Enforcement Team',
        primaryCategory: ReportCategory.parking,
        members: [m('m16', 'Inspector B. Rana', 'Officer'), m('m17', 'Mina Thapa', 'Officer'), m('m18', 'Krishna Dahal', 'Tow Operator', false)],
        status: TeamStatus.busy,
        location: areas['New Road']!,
        locationLabel: 'New Road Patrol',
        activeTasks: 6,
        completedTasks: 341,
        capacity: 8,
      ),
    ]);

    List<GeoPoint> route(List<String> names) => names.map((n) => areas[n]!).toList();
    vehicles.addAll([
      Vehicle(
        id: 'WM-204',
        teamId: 'team-waste',
        driver: 'Gita Tamang',
        position: areas['Tripureshwor']!,
        status: 'On Route',
        route: route(['Teku', 'Tripureshwor', 'Kupondole', 'Baneshwor']),
        loadPercent: 0.46,
      ),
      Vehicle(
        id: 'WM-118',
        teamId: 'team-waste',
        driver: 'Shyam Rai',
        position: areas['Thamel']!,
        status: 'Collecting',
        route: route(['Balaju', 'Thamel', 'Durbarmarg', 'Naxal']),
        loadPercent: 0.72,
      ),
      Vehicle(
        id: 'WM-231',
        teamId: 'team-waste',
        driver: 'Kumar Magar',
        position: areas['Chabahil']!,
        status: 'On Route',
        route: route(['Maharajgunj', 'Chabahil', 'Boudha']),
        loadPercent: 0.31,
      ),
      Vehicle(
        id: 'WM-090',
        teamId: 'team-waste',
        driver: 'Ram B. Shrestha',
        position: areas['Teku']!,
        status: 'Idle',
        route: route(['Teku']),
        loadPercent: 0.0,
      ),
    ]);
  }

  void _seedPoints() {
    var i = 0;
    for (final e in [
      ('Sundhara Dhunge Dhara', 'Sundhara', true, 'High', '5:00 AM – 8:00 PM'),
      ('Putalisadak Water Kiosk', 'Putalisadak', true, 'High', '6:00 AM – 9:00 PM'),
      ('Naxal Community Tap', 'Naxal', true, 'Limited', '6:00 AM – 6:00 PM'),
      ('Kupondole Tanker Point', 'Kupondole', false, 'Closed', 'Opens 6:00 AM'),
      ('Baneshwor Water ATM', 'Baneshwor', true, 'High', '24 hours'),
      ('Patan Manga Hiti', 'Patan Durbar Square', true, 'Medium', '5:00 AM – 7:00 PM'),
    ]) {
      final p = placeFor(e.$2, jitter: 0.003);
      servicePoints.add(ServicePoint(
        id: 'wp-${i++}',
        kind: PointKind.water,
        name: e.$1,
        point: p.point,
        address: p.address,
        hours: e.$5,
        open: e.$3,
        availability: e.$4,
      ));
    }
    for (final e in [
      ('Teku Transfer Station', 'Teku', true, 'All types', '6:00 AM – 6:00 PM'),
      ('Thamel Recycling Hub', 'Thamel', true, 'Recyclables', '8:00 AM – 5:00 PM'),
      ('Baneshwor Collection Point', 'Baneshwor', true, 'Organic, Mixed', '6:00 AM – 10:00 AM'),
      ('Lazimpat Green Bin Bay', 'Lazimpat', false, 'Organic', 'Opens 6:00 AM'),
      ('Jawalakhel E-waste Drop', 'Jawalakhel', true, 'E-waste, Hazardous', '10:00 AM – 4:00 PM'),
    ]) {
      final p = placeFor(e.$2, jitter: 0.003);
      servicePoints.add(ServicePoint(
        id: 'cp-${i++}',
        kind: PointKind.wasteCollection,
        name: e.$1,
        point: p.point,
        address: p.address,
        hours: e.$5,
        open: e.$3,
        availability: e.$4,
      ));
    }
  }

  static const _descriptions = <ReportCategory, List<String>>{
    ReportCategory.waste: [
      'Overflowing community bin; waste spilling onto the footpath.',
      'Garbage dumped beside the river bank near the bridge.',
      'Scheduled pickup missed for three days in this lane.',
    ],
    ReportCategory.parking: [
      'Car parked on the footpath forcing pedestrians onto the road.',
      'Motorbikes blocking the school entrance during pickup hours.',
      'Vehicle parked in a no-parking zone at the junction.',
    ],
    ReportCategory.water: [
      'Burst pipe flooding the road; clean water wasted continuously.',
      'Valve leaking at the corner, water pooling since morning.',
      'Sewage overflowing from manhole after the rain.',
    ],
    ReportCategory.streetlight: [
      'Streetlight not working; the stretch is completely dark at night.',
      'Light flickering constantly near the bus stop.',
      'Streetlight pole leaning dangerously after a vehicle hit it.',
    ],
    ReportCategory.infrastructure: [
      'Open drain cover on a busy footpath, risk to pedestrians.',
      'Broken railing on the pedestrian bridge.',
      'Damaged footpath tiles creating a tripping hazard.',
    ],
    ReportCategory.road: [
      'Large pothole affecting the left side of the roadway.',
      'Road surface cracked and sinking near the junction.',
      'Road flooded after rain; vehicles unable to pass.',
    ],
    ReportCategory.other: ['Stray construction material left on the road.'],
  };

  void _seedReports(DateTime now) {
    final areaNames = areas.keys.toList();
    final cats = ReportCategory.values.where((c) => c != ReportCategory.other).toList();
    final statuses = [
      ReportStatus.submitted,
      ReportStatus.underReview,
      ReportStatus.verified,
      ReportStatus.assigned,
      ReportStatus.inProgress,
      ReportStatus.onTheWay,
      ReportStatus.resolved,
      ReportStatus.resolved,
      ReportStatus.resolved,
      ReportStatus.closed,
      ReportStatus.rejected,
      ReportStatus.reopened,
    ];
    for (var i = 0; i < 46; i++) {
      final cat = cats[i % cats.length];
      final area = areaNames[(i * 7) % areaNames.length];
      final status = statuses[(i * 5) % statuses.length];
      final created = now.subtract(Duration(hours: 2 + i * 9 + _rand.nextInt(6)));
      final sev = Severity.values[(i * 3 + 1) % 4];
      final citizen = users['u-c${i % 10}']!;
      final r = Report(
        id: nextId('r'),
        ticket: 'UE-${10180 + i * 2}',
        category: cat,
        subtype: cat.subtypes[i % cat.subtypes.length],
        description: _descriptions[cat]![i % _descriptions[cat]!.length],
        severity: sev,
        status: status,
        location: placeFor(area),
        createdAt: created,
        updatedAt: created.add(const Duration(hours: 3)),
        citizenId: citizen.id,
        citizenName: citizen.name,
        anonymous: i % 6 == 0,
        evidence: [Evidence(id: nextId('e'), kind: EvidenceKind.photo, sceneSeed: i, capturedAt: created)],
        supporters: _rand.nextInt(14),
        aiAssisted: i % 3 == 0,
        aiConfidence: i % 3 == 0 ? 0.86 + _rand.nextDouble() * 0.1 : null,
        isEmergency: sev == Severity.critical && cat == ReportCategory.water,
      );
      _buildHistory(r, status, created);
      if (status.bucket == StatusBucket.inProgress || status.bucket == StatusBucket.resolved) {
        r.assignment = Assignment(teamId: cat.teamId, teamName: _teamName(cat.teamId), assignedBy: 'Hari Prasad Joshi', at: created.add(const Duration(hours: 2)));
      }
      if (status == ReportStatus.resolved || status == ReportStatus.closed) {
        r.resolvedAt = created.add(Duration(hours: 10 + i % 30));
        r.resolutionNote = 'Issue fixed by ${_teamName(cat.teamId)}. Site inspected and cleared.';
        r.afterEvidence.add(Evidence(id: nextId('e'), kind: EvidenceKind.photo, sceneSeed: i + 1000, capturedAt: r.resolvedAt!, isAfter: true));
      }
      reports[r.id] = r;
    }
  }

  String _teamName(String id) => teams.firstWhere((t) => t.id == id, orElse: () => teams.first).name;

  void _buildHistory(Report r, ReportStatus target, DateTime created) {
    const path = [
      ReportStatus.submitted,
      ReportStatus.underReview,
      ReportStatus.verified,
      ReportStatus.assigned,
      ReportStatus.onTheWay,
      ReportStatus.inProgress,
      ReportStatus.resolved,
      ReportStatus.closed,
    ];
    r.history.add(StatusHistory(status: ReportStatus.submitted, at: created, actor: r.publicCitizenName));
    if (target == ReportStatus.submitted) return;
    if (target == ReportStatus.rejected) {
      r.history.add(StatusHistory(
          status: ReportStatus.rejected,
          at: created.add(const Duration(hours: 2)),
          actor: 'Hari Prasad Joshi',
          note: 'Outside municipal jurisdiction — forwarded to Department of Roads.'));
      return;
    }
    if (target == ReportStatus.reopened) {
      for (final s in path.skip(1).take(6)) {
        r.history.add(StatusHistory(status: s, at: created.add(Duration(hours: r.history.length * 3)), actor: 'Municipality'));
      }
      r.history.add(StatusHistory(
          status: ReportStatus.reopened,
          at: created.add(Duration(hours: r.history.length * 3)),
          actor: r.publicCitizenName,
          note: 'Citizen reported the issue still remains.'));
      r.feedback = CitizenFeedback.remains;
      return;
    }
    for (final s in path.skip(1)) {
      r.history.add(StatusHistory(status: s, at: created.add(Duration(hours: r.history.length * 3)), actor: 'Municipality'));
      if (s == target) break;
    }
  }

  void _seedAlex(DateTime now) {
    final alex = users['u-alex']!;
    final today = DateTime(now.year, now.month, now.day, 10, 32);
    final created = today.isAfter(now) ? now.subtract(const Duration(minutes: 40)) : today;

    Report make({
      required String ticket,
      required ReportCategory cat,
      required String subtype,
      required String desc,
      required Severity sev,
      required ReportStatus status,
      required String area,
      required DateTime at,
      required int seed,
      String? vehicle,
    }) {
      final r = Report(
        id: nextId('r'),
        ticket: ticket,
        category: cat,
        subtype: subtype,
        description: desc,
        severity: sev,
        status: status,
        location: placeFor(area, jitter: 0.001),
        createdAt: at,
        updatedAt: at,
        citizenId: alex.id,
        citizenName: alex.name,
        evidence: [Evidence(id: nextId('e'), kind: EvidenceKind.photo, sceneSeed: seed, capturedAt: at)],
        vehicleNumber: vehicle,
        supporters: seed % 5,
        aiAssisted: true,
        aiConfidence: 0.94,
      );
      _buildHistory(r, status, at);
      if (status.bucket != StatusBucket.pending) {
        r.assignment = Assignment(teamId: cat.teamId, teamName: _teamName(cat.teamId), assignedBy: 'Hari Prasad Joshi', at: at.add(const Duration(hours: 1)), eta: at.add(const Duration(hours: 5)));
      }
      reports[r.id] = r;
      return r;
    }

    final parking = make(
      ticket: 'UE-10284',
      cat: ReportCategory.parking,
      subtype: 'On footpath',
      desc: 'White SUV parked across the footpath outside the school gate, pedestrians forced onto the road.',
      sev: Severity.medium,
      status: ReportStatus.inProgress,
      area: 'Putalisadak',
      at: created,
      seed: 3,
      vehicle: 'BA 2 CHA 4521',
    );
    parking.comments.add(Comment(
        id: nextId('c'),
        authorName: 'Parking Enforcement Team',
        fromMunicipality: true,
        body: 'An officer has been dispatched. Expected on site within 30 minutes.',
        at: created.add(const Duration(minutes: 25))));

    final pothole = make(
      ticket: 'UE-10271',
      cat: ReportCategory.road,
      subtype: 'Pothole',
      desc: 'Large pothole affecting the left side of the roadway near Baneshwor Chowk.',
      sev: Severity.high,
      status: ReportStatus.resolved,
      area: 'Baneshwor',
      at: now.subtract(const Duration(days: 4, hours: 3)),
      seed: 5,
    );
    pothole.resolvedAt = now.subtract(const Duration(days: 1, hours: 2));
    pothole.resolutionNote = 'Pothole filled with hot-mix asphalt and compacted. Lane reopened to traffic.';
    pothole.afterEvidence.add(Evidence(id: nextId('e'), kind: EvidenceKind.photo, sceneSeed: 2005, capturedAt: pothole.resolvedAt!, isAfter: true));

    final light = make(
      ticket: 'UE-10266',
      cat: ReportCategory.streetlight,
      subtype: 'Broken Streetlight',
      desc: 'Streetlight #SL-102 not working, lane is dark after 7 PM.',
      sev: Severity.medium,
      status: ReportStatus.verified,
      area: 'Naxal',
      at: now.subtract(const Duration(days: 2, hours: 5)),
      seed: 7,
    );
    light.comments.add(Comment(
        id: nextId('c'),
        authorName: 'Electrical Team',
        fromMunicipality: true,
        body: 'Could you share a photo of the pole number plate? It helps us bring the right parts.',
        at: now.subtract(const Duration(days: 1, hours: 20)),
        isQuestion: true));

    make(
      ticket: 'UE-10259',
      cat: ReportCategory.water,
      subtype: 'Burst pipe',
      desc: 'Burst pipe flooding the lane behind the temple, water wasted continuously.',
      sev: Severity.critical,
      status: ReportStatus.closed,
      area: 'Sundhara',
      at: now.subtract(const Duration(days: 9)),
      seed: 2,
    )
      ..resolvedAt = now.subtract(const Duration(days: 8, hours: 18))
      ..resolutionNote = 'Pipe section replaced by KUKL crew.'
      ..feedback = CitizenFeedback.resolved;

    make(
      ticket: 'UE-10248',
      cat: ReportCategory.waste,
      subtype: 'Overflowing bin',
      desc: 'Community bin overflowing for two days, waste spreading onto the street.',
      sev: Severity.medium,
      status: ReportStatus.submitted,
      area: 'Putalisadak',
      at: now.subtract(const Duration(hours: 5)),
      seed: 1,
    );

    make(
      ticket: 'UE-10233',
      cat: ReportCategory.infrastructure,
      subtype: 'Open drain / manhole',
      desc: 'Open manhole on the footpath without any barrier.',
      sev: Severity.high,
      status: ReportStatus.assigned,
      area: 'Durbarmarg',
      at: now.subtract(const Duration(days: 1, hours: 4)),
      seed: 4,
    );
  }

  void _seedPickups(DateTime now) {
    pickups.add(WastePickup(
      id: nextId('p'),
      ticket: 'UE-10283',
      citizenId: 'u-alex',
      wasteType: WasteType.organic,
      location: placeFor('Putalisadak', jitter: 0.0008),
      description: 'Two sacks of kitchen and garden waste.',
      preference: 'Morning (6–10 AM)',
      createdAt: now.subtract(const Duration(hours: 2)),
      status: PickupStatus.assigned,
      vehicleId: 'WM-204',
      teamId: 'team-waste',
      eta: now.add(const Duration(minutes: 18)),
    ));
    for (var i = 0; i < 7; i++) {
      final area = areas.keys.elementAt((i * 3) % areas.length);
      pickups.add(WastePickup(
        id: nextId('p'),
        ticket: 'UE-${10150 + i}',
        citizenId: 'u-c$i',
        wasteType: WasteType.values[i % 3],
        location: placeFor(area),
        description: 'Household waste pickup request.',
        preference: i.isEven ? 'Morning (6–10 AM)' : 'Afternoon (12–4 PM)',
        createdAt: now.subtract(Duration(hours: 1 + i * 4)),
        status: [PickupStatus.submitted, PickupStatus.notified, PickupStatus.assigned, PickupStatus.enRoute, PickupStatus.collected][i % 5],
        vehicleId: i % 5 >= 2 ? vehicles[i % 3].id : null,
        teamId: i % 5 >= 2 ? 'team-waste' : null,
      ));
    }
  }

  void _seedNotifications(DateTime now) {
    final alexReports = reports.values.where((r) => r.citizenId == 'u-alex').toList();
    String? idOf(String t) => alexReports.where((r) => r.ticket == t).map((r) => r.id).firstOrNull;
    final items = [
      (NotificationType.pickupScheduled, 'Waste pickup assigned', 'Truck WM-204 will collect your waste in about 18 minutes.', 30, null as String?, false),
      (NotificationType.statusChanged, 'Team on the way', 'Parking Enforcement Team is heading to UE-10284.', 50, idOf('UE-10284'), false),
      (NotificationType.question, 'Municipality requested more information', 'Electrical Team asked a question on UE-10266.', 60 * 20, idOf('UE-10266'), false),
      (NotificationType.resolved, 'Issue resolved', 'UE-10271 (Pothole) was marked resolved. Please confirm the fix.', 60 * 26, idOf('UE-10271'), false),
      (NotificationType.verified, 'Report verified', 'UE-10266 was verified by Kathmandu Metropolitan City.', 60 * 50, idOf('UE-10266'), true),
      (NotificationType.pickupDelayed, 'Pickup delayed', 'Heavy traffic at Kalanki — your previous pickup was delayed by 20 min.', 60 * 72, null, true),
    ];
    for (final i in items) {
      notifications.add(AppNotification(
        id: nextId('n'),
        userId: 'u-alex',
        type: i.$1,
        title: i.$2,
        body: i.$3,
        at: now.subtract(Duration(minutes: i.$4)),
        reportId: i.$5,
        read: i.$6,
      ));
    }
  }
}
