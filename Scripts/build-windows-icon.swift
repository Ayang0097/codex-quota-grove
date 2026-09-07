#!/usr/bin/env swift

import Foundation

private let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("用法：build-windows-icon.swift <master-png> <output-ico>\n".utf8))
    exit(64)
}

private let fileManager = FileManager.default
private let masterURL = URL(fileURLWithPath: arguments[1])
private let outputURL = URL(fileURLWithPath: arguments[2])
private let sizes = [16, 24, 32, 48, 64, 128, 256]
private let temporaryDirectory = fileManager.temporaryDirectory
    .appendingPathComponent("quota-grove-icon-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)

private func appendUInt16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
}

private func appendUInt32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}

do {
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    var images: [(size: Int, data: Data)] = []
    for size in sizes {
        let imageURL = temporaryDirectory.appendingPathComponent("icon-\(size).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = [
            "-z", String(size), String(size),
            masterURL.path,
            "--out", imageURL.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "QuotaGroveIcon", code: Int(process.terminationStatus))
        }
        images.append((size, try Data(contentsOf: imageURL)))
    }

    var icon = Data()
    appendUInt16(0, to: &icon)
    appendUInt16(1, to: &icon)
    appendUInt16(UInt16(images.count), to: &icon)

    var offset = UInt32(6 + images.count * 16)
    for image in images {
        icon.append(image.size == 256 ? 0 : UInt8(image.size))
        icon.append(image.size == 256 ? 0 : UInt8(image.size))
        icon.append(0)
        icon.append(0)
        appendUInt16(1, to: &icon)
        appendUInt16(32, to: &icon)
        appendUInt32(UInt32(image.data.count), to: &icon)
        appendUInt32(offset, to: &icon)
        offset += UInt32(image.data.count)
    }
    for image in images { icon.append(image.data) }

    try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try icon.write(to: outputURL, options: .atomic)
    print(outputURL.path)
} catch {
    FileHandle.standardError.write(Data("Windows 图标生成失败：\(error.localizedDescription)\n".utf8))
    exit(1)
}
