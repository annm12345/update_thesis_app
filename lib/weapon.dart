import 'dart:math';

class Weapon {
  final String name;
  final double range; // in meters
  final double bulletFlightTime; // in seconds
  final double gunPower; // arbitrary unit
  final double longDistance; // in meters
  final int id; // ID for each weapon

  Weapon({
    required this.name,
    required this.range,
    required this.bulletFlightTime,
    required this.gunPower,
    required this.longDistance,
    required this.id,
  });
}

// Helper function to calculate bullet flight time for MA7
double calculateBulletFlightTimeMA7(double range, double gunPower) {
  return range / (300 + (gunPower * 50)); // Example formula: adjust as needed
}

// Helper function to calculate long distance for MA7
double calculateLongDistanceMA7(double range) {
  return range * 1.2; // Example formula: adjust as needed
}

// Helper function to calculate bullet flight time for MA8
double calculateBulletFlightTimeMA8(double range, double gunPower) {
  return range / (350 + (gunPower * 40)); // Example formula: adjust as needed
}

// Helper function to calculate long distance for MA8
double calculateLongDistanceMA8(double range, double gunPower) {
  return range + (gunPower * 100); // Example formula: adjust as needed
}

// Generate MA7 weapons
final List<Weapon> ma7Weapons = List.generate(4351, (index) {
  double range = 250 + index.toDouble();
  double gunPower = 0.0;
  double bulletFlightTime = 0.0;
  double longDistance = 0.0;

  if (range >= 250 && range <= 750) {
    gunPower = 0;
  } else if (range > 750 && range <= 1550) {
    gunPower = 1;
  } else if (range > 1550 && range <= 2150) {
    gunPower = 2;
  } else if (range > 2150 && range <= 2900) {
    gunPower = 3;
  } else if (range > 2900 && range <= 3480) {
    gunPower = 4;
  } else if (range > 3480 && range <= 4050) {
    gunPower = 5;
  } else if (range > 4050 && range <= 4600) {
    gunPower = 6;
  }

  bulletFlightTime = calculateBulletFlightTimeMA7(range, gunPower);
  longDistance = calculateLongDistanceMA7(range);

  return Weapon(
    name: 'MA7',
    range: range,
    gunPower: gunPower,
    bulletFlightTime: bulletFlightTime,
    longDistance: longDistance,
    id: index,
  );
});

// Generate MA8 weapons
final List<Weapon> ma8Weapons = List.generate(6151, (index) {
  double range = 200 + index.toDouble();
  double gunPower = 0.0;
  double bulletFlightTime = 0.0;
  double longDistance = 0.0;

  if (range >= 200 && range <= 550) {
    gunPower = 0;
  } else if (range > 550 && range <= 1125) {
    gunPower = 1;
  } else if (range > 1125 && range <= 1650) {
    gunPower = 2;
  } else if (range > 1650 && range <= 2700) {
    gunPower = 3;
  } else if (range > 2700 && range <= 3550) {
    gunPower = 4;
  } else if (range > 3550 && range <= 4400) {
    gunPower = 5;
  } else if (range > 4400 && range <= 5150) {
    gunPower = 6;
  } else if (range > 5150 && range <= 5800) {
    gunPower = 7;
  } else if (range > 5800 && range <= 6350) {
    gunPower = 8;
  }

  bulletFlightTime = calculateBulletFlightTimeMA8(range, gunPower);
  longDistance = calculateLongDistanceMA8(range, gunPower);

  return Weapon(
    name: 'MA8',
    range: range,
    gunPower: gunPower,
    bulletFlightTime: bulletFlightTime,
    longDistance: longDistance,
    id: index,
  );
});
