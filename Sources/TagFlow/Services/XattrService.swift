import Foundation

enum XattrError: LocalizedError {
    case notSupported(URL)
    case permissionDenied(URL)
    case readFailed(URL, Int32)
    case writeFailed(URL, Int32)

    var errorDescription: String? {
        switch self {
        case .notSupported(let url):
            return "このボリュームはタグをサポートしていません: \(url.lastPathComponent)"
        case .permissionDenied(let url):
            return "タグの書き込み権限がありません: \(url.lastPathComponent)"
        case .readFailed(let url, let code):
            return "タグの読み取りに失敗しました (code \(code)): \(url.lastPathComponent)"
        case .writeFailed(let url, let code):
            return "タグの書き込みに失敗しました (code \(code)): \(url.lastPathComponent)"
        }
    }
}

enum XattrService {
    static let tagXattrKey = "com.apple.metadata:_kMDItemUserTags"

    // Returns raw Finder tag strings e.g. ["Work", "Urgent\n6"]
    static func readFinderTagStrings(from url: URL) throws -> [String] {
        let path = url.resolvingSymlinksInPath().path
        let bufSize = getxattr(path, tagXattrKey, nil, 0, 0, 0)
        guard bufSize > 0 else {
            if bufSize == 0 { return [] }
            let err = errno
            if err == ENOATTR { return [] }
            throw XattrError.readFailed(url, err)
        }
        var buffer = [UInt8](repeating: 0, count: bufSize)
        let result = getxattr(path, tagXattrKey, &buffer, bufSize, 0, 0)
        if result < 0 {
            throw XattrError.readFailed(url, errno)
        }
        let data = Data(buffer)
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let array = plist as? [String] else {
            return []
        }
        return array
    }

    // Returns tag names without color suffix
    static func readTagNames(from url: URL) throws -> [String] {
        let raw = try readFinderTagStrings(from: url)
        return raw.map { $0.components(separatedBy: "\n").first ?? $0 }
    }

    static func write(tags: [Tag], to url: URL) throws {
        let path = url.resolvingSymlinksInPath().path
        let finderStrings = tags.map(\.finderString)

        if finderStrings.isEmpty {
            let r = removexattr(path, tagXattrKey, 0)
            if r != 0 && errno != ENOATTR {
                throw makeWriteError(errno, url: url)
            }
            return
        }

        let data = try PropertyListSerialization.data(
            fromPropertyList: finderStrings,
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes { ptr -> Int32 in
            setxattr(path, tagXattrKey, ptr.baseAddress, data.count, 0, 0)
        }
        if result != 0 {
            throw makeWriteError(errno, url: url)
        }
    }

    static func addTag(_ tag: Tag, to url: URL) throws {
        var existing = try readFinderTagStrings(from: url)
        // Remove old entry for this tag name (may have different color)
        existing.removeAll { $0 == tag.name || $0.hasPrefix(tag.name + "\n") }
        existing.append(tag.finderString)
        let path = url.resolvingSymlinksInPath().path
        let data = try PropertyListSerialization.data(
            fromPropertyList: existing,
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes { ptr -> Int32 in
            setxattr(path, tagXattrKey, ptr.baseAddress, data.count, 0, 0)
        }
        if result != 0 {
            throw makeWriteError(errno, url: url)
        }
    }

    static func removeTag(_ tag: Tag, from url: URL) throws {
        var existing = try readFinderTagStrings(from: url)
        existing.removeAll { $0 == tag.name || $0.hasPrefix(tag.name + "\n") }
        try writeRawStrings(existing, to: url)
    }

    // Write raw Finder tag strings (may include color suffix like "Work\n6")
    private static func writeRawStrings(_ tagStrings: [String], to url: URL) throws {
        let path = url.resolvingSymlinksInPath().path
        if tagStrings.isEmpty {
            let r = removexattr(path, tagXattrKey, 0)
            if r != 0 && errno != ENOATTR {
                throw makeWriteError(errno, url: url)
            }
            return
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: tagStrings,
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes { ptr -> Int32 in
            setxattr(path, tagXattrKey, ptr.baseAddress, data.count, 0, 0)
        }
        if result != 0 {
            throw makeWriteError(errno, url: url)
        }
    }

    private static func makeWriteError(_ err: Int32, url: URL) -> XattrError {
        switch err {
        case ENOTSUP: return .notSupported(url)
        case EPERM, EACCES: return .permissionDenied(url)
        default: return .writeFailed(url, err)
        }
    }
}
