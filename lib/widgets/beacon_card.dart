import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../services/ble_scanner_service.dart';

/// Reusable beacon card — neumorphic style, displays a detected BLE beacon
///
/// Used in the faculty dashboard to show nearby ESP32 beacons.
class BeaconCard extends StatelessWidget {
  final DetectedBeacon beacon;
  final bool isClosest;
  final int animationIndex;

  const BeaconCard({
    super.key,
    required this.beacon,
    this.isClosest = false,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.neumorphicDecoration(
              borderRadius: 20,
              blurRadius: 10,
            ),
            child: Row(
              children: [
                // Neumorphic inset bluetooth icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: AppTheme.neumorphicInsetDecoration(
                    borderRadius: 12,
                  ),
                  child: Icon(
                    Icons.bluetooth_rounded,
                    color: isClosest ? AppTheme.success : AppTheme.primary,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Beacon info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beacon.roomId,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        beacon.deviceName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),

                // Signal info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      beacon.signalLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isClosest
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${beacon.rssi} dBm',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                    if (isClosest)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: AppTheme.neumorphicInsetDecoration(
                          borderRadius: 8,
                        ),
                        child: Text(
                          'CLOSEST',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 400 + animationIndex * 80))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms);
  }
}
