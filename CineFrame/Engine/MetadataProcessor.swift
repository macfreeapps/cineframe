import Foundation
import ImageIO

struct MetadataOptions: Sendable {
    var stripGPS = false
    var addCinematicKeyword = false
}

enum MetadataProcessor {
    static let appVersion = "1.0"

    static func update(_ source: CGImageMetadata?, properties sourceProperties: [String: Any],
                       outputSize: PixelSize, crop: PixelRect, sourceURL: URL, barColor: BarColor,
                       options: MetadataOptions, now: Date = Date()) -> CGMutableImageMetadata {
        let metadata = source.flatMap { CGImageMetadataCreateMutableCopy($0) } ?? CGImageMetadataCreateMutable()
        let software = "CineFrame \(appVersion)" as CFString
        let date = iso8601(now) as CFString

        _ = CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespaceTIFF,
                                                      kCGImageMetadataPrefixTIFF, nil)
        _ = CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespaceExif,
                                                      kCGImageMetadataPrefixExif, nil)
        _ = CGImageMetadataRegisterNamespaceForPrefix(metadata, kCGImageMetadataNamespaceXMPBasic,
                                                      kCGImageMetadataPrefixXMPBasic, nil)
        setMatching(metadata, dictionary: kCGImagePropertyTIFFDictionary,
                    property: kCGImagePropertyTIFFOrientation, value: NSNumber(value: 1))
        setMatching(metadata, dictionary: kCGImagePropertyTIFFDictionary,
                    property: "ImageWidth" as CFString, value: NSNumber(value: outputSize.width))
        setMatching(metadata, dictionary: kCGImagePropertyTIFFDictionary,
                    property: "ImageLength" as CFString, value: NSNumber(value: outputSize.height))
        setMatching(metadata, dictionary: kCGImagePropertyTIFFDictionary,
                    property: kCGImagePropertyTIFFSoftware, value: software)
        setMatching(metadata, dictionary: kCGImagePropertyExifDictionary,
                    property: kCGImagePropertyExifPixelXDimension, value: NSNumber(value: outputSize.width))
        setMatching(metadata, dictionary: kCGImagePropertyExifDictionary,
                    property: kCGImagePropertyExifPixelYDimension, value: NSNumber(value: outputSize.height))
        setTag(metadata, namespace: kCGImageMetadataNamespaceTIFF, prefix: kCGImageMetadataPrefixTIFF,
               name: "Orientation", path: "tiff:Orientation", value: NSNumber(value: 1))
        setTag(metadata, namespace: kCGImageMetadataNamespaceTIFF, prefix: kCGImageMetadataPrefixTIFF,
               name: "ImageWidth", path: "tiff:ImageWidth", value: NSNumber(value: outputSize.width))
        setTag(metadata, namespace: kCGImageMetadataNamespaceTIFF, prefix: kCGImageMetadataPrefixTIFF,
               name: "ImageLength", path: "tiff:ImageLength", value: NSNumber(value: outputSize.height))
        setTag(metadata, namespace: kCGImageMetadataNamespaceTIFF, prefix: kCGImageMetadataPrefixTIFF,
               name: "Software", path: "tiff:Software", value: software)
        setTag(metadata, namespace: kCGImageMetadataNamespaceExif, prefix: kCGImageMetadataPrefixExif,
               name: "PixelXDimension", path: "exif:PixelXDimension", value: NSNumber(value: outputSize.width))
        setTag(metadata, namespace: kCGImageMetadataNamespaceExif, prefix: kCGImageMetadataPrefixExif,
               name: "PixelYDimension", path: "exif:PixelYDimension", value: NSNumber(value: outputSize.height))
        set(metadata, "xmp:ModifyDate", date)
        set(metadata, "xmp:MetadataDate", date)

        let cineURI = "http://ns.cineframe.app/1.0/" as CFString
        _ = CGImageMetadataRegisterNamespaceForPrefix(metadata, cineURI, "cineframe" as CFString, nil)
        set(metadata, "cineframe:CropRatio", NSNumber(value: CinematicGeometry.cropRatio))
        set(metadata, "cineframe:CanvasRatio", "16:9" as CFString)
        set(metadata, "cineframe:CropRect", "\(crop.x),\(crop.y),\(crop.width),\(crop.height)" as CFString)
        set(metadata, "cineframe:BarColor", barColor.rawValue as CFString)
        set(metadata, "cineframe:SourceFile", sourceURL.lastPathComponent as CFString)

        appendHistoryEvent(to: metadata, software: software, date: date)

        for stalePath in ["mwg-rs:Regions", "apple-fi:Faces", "apple:Faces", "MP:RegionInfo", "exif:SubjectArea"] {
            _ = CGImageMetadataRemoveTagWithPath(metadata, nil, stalePath as CFString)
        }
        if options.stripGPS {
            for path in ["exif:GPSLatitude", "exif:GPSLongitude", "exif:GPSAltitude", "exif:GPSLatitudeRef",
                         "exif:GPSLongitudeRef", "exif:GPSAltitudeRef", "exif:GPSTimeStamp", "exif:GPSDateStamp"] {
                _ = CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
            }
        }
        if options.addCinematicKeyword { appendKeyword("Cinematic", to: metadata) }

        // EXIF/TIFF property dictionaries are separately merged into the destination.
        _ = sourceProperties
        return metadata
    }

    static func outputProperties(from original: [String: Any], outputSize: PixelSize,
                                 options: MetadataOptions, software: String = "CineFrame \(appVersion)") -> [String: Any] {
        var properties = original
        properties[kCGImagePropertyPixelWidth as String] = outputSize.width
        properties[kCGImagePropertyPixelHeight as String] = outputSize.height
        properties[kCGImagePropertyOrientation as String] = 1
        var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation as String] = 1
        tiff["ImageWidth"] = outputSize.width
        tiff["ImageLength"] = outputSize.height
        tiff[kCGImagePropertyTIFFSoftware as String] = software
        tiff[kCGImagePropertyTIFFCompression as String] = 5 // TIFF LZW
        properties[kCGImagePropertyTIFFDictionary as String] = tiff

        var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exif[kCGImagePropertyExifPixelXDimension as String] = outputSize.width
        exif[kCGImagePropertyExifPixelYDimension as String] = outputSize.height
        exif.removeValue(forKey: kCGImagePropertyExifSubjectArea as String)
        properties[kCGImagePropertyExifDictionary as String] = exif
        for key in ["{MakerApple}", "AppleFaceRegions", "RegionInfo"] { properties.removeValue(forKey: key) }
        if options.stripGPS { properties.removeValue(forKey: kCGImagePropertyGPSDictionary as String) }
        return properties
    }

    private static func appendHistoryEvent(to metadata: CGMutableImageMetadata, software: CFString, date: CFString) {
        let xmpMM = "http://ns.adobe.com/xap/1.0/mm/" as CFString
        let eventURI = "http://ns.adobe.com/xap/1.0/sType/ResourceEvent#" as CFString
        _ = CGImageMetadataRegisterNamespaceForPrefix(metadata, xmpMM, "xmpMM" as CFString, nil)
        _ = CGImageMetadataRegisterNamespaceForPrefix(metadata, eventURI, "stEvt" as CFString, nil)

        let values: [(String, CFTypeRef)] = [
            ("action", "derived" as CFString),
            ("softwareAgent", software),
            ("when", date),
            ("parameters", "cropped to 2.39:1, letterboxed to 16:9" as CFString)
        ]
        var fields: [CFString: Any] = [:]
        for (name, value) in values {
            guard let tag = CGImageMetadataTagCreate(eventURI, "stEvt" as CFString, name as CFString,
                                                    .default, value) else { continue }
            fields[name as CFString] = tag
        }
        guard let event = CGImageMetadataTagCreate(eventURI, "stEvt" as CFString, "ResourceEvent" as CFString,
                                                   .structure, fields as CFDictionary) else { return }

        var history: [Any] = []
        if let existing = CGImageMetadataCopyTagWithPath(metadata, nil, "xmpMM:History" as CFString),
           let value = CGImageMetadataTagCopyValue(existing), let array = value as? [Any] {
            history = array
        }
        history.append(event)
        guard let historyTag = CGImageMetadataTagCreate(xmpMM, "xmpMM" as CFString, "History" as CFString,
                                                       .arrayOrdered, history as CFArray) else { return }
        _ = CGImageMetadataSetTagWithPath(metadata, nil, "xmpMM:History" as CFString, historyTag)
    }

    private static func appendKeyword(_ word: String, to metadata: CGMutableImageMetadata) {
        guard let tag = CGImageMetadataCopyTagWithPath(metadata, nil, "dc:subject" as CFString),
              let value = CGImageMetadataTagCopyValue(tag),
              let subjects = value as? [String] else {
            set(metadata, "dc:subject[0]", word as CFString)
            return
        }
        guard !subjects.contains(word) else { return }
        set(metadata, "dc:subject[\(subjects.count)]", word as CFString)
    }

    private static func set(_ metadata: CGMutableImageMetadata, _ path: String, _ value: CFTypeRef) {
        _ = CGImageMetadataSetValueWithPath(metadata, nil, path as CFString, value)
    }

    private static func setMatching(_ metadata: CGMutableImageMetadata, dictionary: CFString,
                                    property: CFString, value: CFTypeRef) {
        _ = CGImageMetadataSetValueMatchingImageProperty(metadata, dictionary, property, value)
    }

    private static func setTag(_ metadata: CGMutableImageMetadata, namespace: CFString, prefix: CFString,
                               name: String, path: String, value: CFTypeRef) {
        guard let tag = CGImageMetadataTagCreate(namespace, prefix, name as CFString, .default, value) else { return }
        _ = CGImageMetadataSetTagWithPath(metadata, nil, path as CFString, tag)
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
