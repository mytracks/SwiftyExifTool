/// Tags of the GPS IFD (CIPA DC-008-2026, Exif 3.1, section 4.6.7).
///
/// IDs, types and reference values from the cited sections. Names and
/// display texts follow exiftool's observable output (exiftool 13.55,
/// fixtures `gps-all-tags`, `gps-refs-*`, `gps-coordinates`, `gps-timestamp-*`).
enum GPSTags {
    private static func gps(_ id: UInt16, _ name: String, value: ValueConversion = .automatic,
                            display: DisplayConversion = .none, _ section: String) -> TagDefinition {
        TagDefinition(id, name, table: .gps, value: value, display: display, source: .exif(section))
    }

    private static let north: [String: String] = ["N": "North", "S": "South"]
    private static let east: [String: String] = ["E": "East", "W": "West"]
    private static let direction: [String: String] = ["T": "True North", "M": "Magnetic North"]

    static let all: [TagDefinition] = [
        gps(0x0000, "GPSVersionID", display: .formatter(.dottedVersion), "4.6.7.1.1"),
        gps(0x0001, "GPSLatitudeRef", display: .stringEnumeration(north), "4.6.7.1.2"),
        gps(0x0002, "GPSLatitude", value: .gpsCoordinate, display: .formatter(.gpsCoordinate), "4.6.7.1.3"),
        gps(0x0003, "GPSLongitudeRef", display: .stringEnumeration(east), "4.6.7.1.4"),
        gps(0x0004, "GPSLongitude", value: .gpsCoordinate, display: .formatter(.gpsCoordinate), "4.6.7.1.5"),
        gps(0x0005, "GPSAltitudeRef", display: .enumeration([
            0: "Above Sea Level",
            1: "Below Sea Level",
            2: "Positive Sea Level (sea-level ref)",
            3: "Negative Sea Level (sea-level ref)",
        ]), "4.6.7.1.6"),
        gps(0x0006, "GPSAltitude", display: .formatter(.suffix("m")), "4.6.7.1.7"),
        gps(0x0007, "GPSTimeStamp", value: .gpsTimeStamp, "4.6.7.1.8"),
        gps(0x0008, "GPSSatellites", "4.6.7.1.9"),
        gps(0x0009, "GPSStatus", display: .stringEnumeration([
            "A": "Measurement Active", "V": "Measurement Void",
        ]), "4.6.7.1.10"),
        gps(0x000A, "GPSMeasureMode", display: .stringEnumeration([
            "2": "2-Dimensional Measurement", "3": "3-Dimensional Measurement",
        ]), "4.6.7.1.11"),
        gps(0x000B, "GPSDOP", "4.6.7.1.12"),
        gps(0x000C, "GPSSpeedRef", display: .stringEnumeration([
            "K": "km/h", "M": "mph", "N": "knots",
        ]), "4.6.7.1.13"),
        gps(0x000D, "GPSSpeed", "4.6.7.1.14"),
        gps(0x000E, "GPSTrackRef", display: .stringEnumeration(direction), "4.6.7.1.15"),
        gps(0x000F, "GPSTrack", "4.6.7.1.16"),
        gps(0x0010, "GPSImgDirectionRef", display: .stringEnumeration(direction), "4.6.7.1.17"),
        gps(0x0011, "GPSImgDirection", "4.6.7.1.18"),
        gps(0x0012, "GPSMapDatum", "4.6.7.1.19"),
        gps(0x0013, "GPSDestLatitudeRef", display: .stringEnumeration(north), "4.6.7.1.20"),
        gps(0x0014, "GPSDestLatitude", value: .gpsCoordinate, display: .formatter(.gpsCoordinate), "4.6.7.1.21"),
        gps(0x0015, "GPSDestLongitudeRef", display: .stringEnumeration(east), "4.6.7.1.22"),
        gps(0x0016, "GPSDestLongitude", value: .gpsCoordinate, display: .formatter(.gpsCoordinate), "4.6.7.1.23"),
        gps(0x0017, "GPSDestBearingRef", display: .stringEnumeration(direction), "4.6.7.1.24"),
        gps(0x0018, "GPSDestBearing", "4.6.7.1.25"),
        gps(0x0019, "GPSDestDistanceRef", display: .stringEnumeration([
            "K": "Kilometers", "M": "Miles", "N": "Nautical Miles",
        ]), "4.6.7.1.26"),
        gps(0x001A, "GPSDestDistance", "4.6.7.1.27"),
        gps(0x001B, "GPSProcessingMethod", value: .characterCodedText, "4.6.7.1.28; 4.6.4"),
        gps(0x001C, "GPSAreaInformation", value: .characterCodedText, "4.6.7.1.29; 4.6.4"),
        gps(0x001D, "GPSDateStamp", "4.6.7.1.30"),
        gps(0x001E, "GPSDifferential", display: .enumeration([
            0: "No Correction",
            1: "Differential Corrected",
        ]), "4.6.7.1.31"),
        gps(0x001F, "GPSHPositioningError", display: .formatter(.suffix("m")), "4.6.7.1.32"),
    ]
}
