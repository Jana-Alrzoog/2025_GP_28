import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/*Station Model*/
class Station {
  final String name;
  final String? altName;
  final LatLng position;
  final Set<String> lines;
  final List<Color> colors;

  const Station({
    required this.name,
    required this.position,
    required this.lines,
    required this.colors,
    this.altName,
  });
}
