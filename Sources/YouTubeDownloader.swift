import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Darwin
import CryptoKit

@MainActor
final class DownloadModel: ObservableObject {
    @Published var url = ""
    @Published var folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    @Published var format = 0
    @Published var downloadQuality = 0
    @Published var audioQuality = 1
    @Published var selectedTab = 0
    @Published var converterSource: URL?
    @Published var converterPreset = 0
    @Published var converterQuality = 0
    @Published var status = "Paste a YouTube link to get started."
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var log = ""
    @Published var phase = "Ready"
    @Published var autoUpdateYTDLP: Bool {
        didSet { UserDefaults.standard.set(autoUpdateYTDLP, forKey: "autoUpdateYTDLP") }
    }
    @Published var isCheckingForUpdates = false
    @Published var updateStatus = "Ready to check for yt-dlp updates."
    @Published var latestYTDLPVersion: String?

    private var process: Process?
    private var partialLine = ""
    private var downloadedFile: URL?
    @Published var latestOutput: URL?
    private var duration: Double = 0
    private var cancelled = false
    private var filesBeforeDownload: Set<String>?
    private let bundledYTDLPVersion = "2026.08.19"
    private let managedVersionKey = "managedYTDLPVersion"
    private let lastUpdateCheckKey = "lastYTDLPUpdateCheck"

    init() {
        if UserDefaults.standard.object(forKey: "autoUpdateYTDLP") == nil {
            autoUpdateYTDLP = true
        } else {
            autoUpdateYTDLP = UserDefaults.standard.bool(forKey: "autoUpdateYTDLP")
        }
    }

    var activeYTDLPVersion: String {
        if FileManager.default.isExecutableFile(atPath: managedYTDLPURL.path),
           let managed = UserDefaults.standard.string(forKey: managedVersionKey) {
            return managed + " (updated)"
        }
        return bundledYTDLPVersion + " (built in)"
    }

    var managedYTDLPFolder: String { managedToolsDirectory.path }
    var hasManagedYTDLP: Bool { FileManager.default.isExecutableFile(atPath: managedYTDLPURL.path) }

    func checkAutomaticallyIfNeeded() {
        guard autoUpdateYTDLP else { return }
        if let last = UserDefaults.standard.object(forKey: lastUpdateCheckKey) as? Date,
           Date().timeIntervalSince(last) < 6 * 60 * 60 { return }
        checkForYTDLPUpdates()
    }

    func checkForYTDLPUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateStatus = "Checking GitHub for yt-dlp updates…"
        UserDefaults.standard.set(Date(), forKey: lastUpdateCheckKey)

        Task {
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("YouTubeDownloader/2.6.1", forHTTPHeaderField: "User-Agent")
                let (releaseData, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw UpdateError.message("GitHub returned an unexpected response.")
                }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: releaseData)
                latestYTDLPVersion = release.tagName

                let installed = UserDefaults.standard.string(forKey: managedVersionKey) ?? bundledYTDLPVersion
                guard Self.isNewerVersion(release.tagName, than: installed) else {
                    updateStatus = "yt-dlp \(installed) is up to date."
                    isCheckingForUpdates = false
                    return
                }
                guard let asset = release.assets.first(where: { $0.name == "yt-dlp_macos" }),
                      let expected = asset.digest?.replacingOccurrences(of: "sha256:", with: ""),
                      expected.count == 64 else {
                    throw UpdateError.message("The release does not include a verifiable macOS asset.")
                }

                updateStatus = "Downloading yt-dlp \(release.tagName)…"
                let (binary, assetResponse) = try await URLSession.shared.data(from: asset.downloadURL)
                guard let assetHTTP = assetResponse as? HTTPURLResponse, assetHTTP.statusCode == 200 else {
                    throw UpdateError.message("The yt-dlp download failed.")
                }
                let actual = SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()
                guard actual == expected.lowercased() else {
                    throw UpdateError.message("The downloaded yt-dlp checksum did not match GitHub.")
                }
                guard binary.count > 1_000_000 else {
                    throw UpdateError.message("The downloaded yt-dlp file was unexpectedly small.")
                }

                try FileManager.default.createDirectory(at: managedToolsDirectory, withIntermediateDirectories: true)
                let temporary = managedToolsDirectory.appendingPathComponent("yt-dlp.download")
                try binary.write(to: temporary, options: .atomic)
                guard chmod(temporary.path, S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH) == 0 else {
                    throw UpdateError.message("The downloaded tool could not be made executable.")
                }
                if FileManager.default.fileExists(atPath: managedYTDLPURL.path) {
                    _ = try FileManager.default.replaceItemAt(managedYTDLPURL, withItemAt: temporary)
                } else {
                    try FileManager.default.moveItem(at: temporary, to: managedYTDLPURL)
                }
                UserDefaults.standard.set(release.tagName, forKey: managedVersionKey)
                updateStatus = "Updated yt-dlp to \(release.tagName). New downloads will use it."
            } catch {
                updateStatus = "Update check failed: \(error.localizedDescription)"
            }
            isCheckingForUpdates = false
        }
    }

    func restoreBundledYTDLP() {
        guard !isDownloading && !isCheckingForUpdates else { return }
        do {
            if FileManager.default.fileExists(atPath: managedYTDLPURL.path) {
                try FileManager.default.removeItem(at: managedYTDLPURL)
            }
            UserDefaults.standard.removeObject(forKey: managedVersionKey)
            latestYTDLPVersion = nil
            updateStatus = "Restored built-in yt-dlp \(bundledYTDLPVersion)."
        } catch {
            updateStatus = "Could not restore the built-in version: \(error.localizedDescription)"
        }
    }

    func showManagedToolsFolder() {
        try? FileManager.default.createDirectory(at: managedToolsDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([managedToolsDirectory])
    }

    private var managedToolsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("YouTube Downloader", isDirectory: true)
            .appendingPathComponent("Tools", isDirectory: true)
    }

    private var managedYTDLPURL: URL { managedToolsDirectory.appendingPathComponent("yt-dlp") }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [GitHubAsset]
        enum CodingKeys: String, CodingKey { case tagName = "tag_name"; case assets }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let downloadURL: URL
        let digest: String?
        enum CodingKeys: String, CodingKey { case name; case downloadURL = "browser_download_url"; case digest }
    }

    private enum UpdateError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
    }

    private static func isNewerVersion(_ candidate: String, than installed: String) -> Bool {
        candidate.compare(installed, options: .numeric) == .orderedDescending
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        if panel.runModal() == .OK, let selection = panel.url { folder = selection }
    }

    func openFolder() {
        if let latestOutput { NSWorkspace.shared.activateFileViewerSelecting([latestOutput]) }
        else if selectedTab == 1, let converterSource { NSWorkspace.shared.open(converterSource.deletingLastPathComponent()) }
        else { NSWorkspace.shared.open(folder) }
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a video to convert for QuickTime."
        guard panel.runModal() == .OK, let file = panel.url else { return }
        converterSource = file
        status = "Ready to convert \(file.lastPathComponent)."
        phase = "Ready"
        progress = 0
        latestOutput = nil
    }

    func startConversion() {
        guard let file = converterSource else {
            status = "Choose a video first."
            return
        }
        guard executable("ffmpeg") != nil, executable("ffprobe") != nil else {
            status = "The app’s built-in media tools are missing. Reinstall the app."
            return
        }
        log = ""
        latestOutput = nil
        cancelled = false
        isDownloading = true
        convert(file, preset: converterPreset, quality: converterQuality)
    }

    func start() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let link = URL(string: trimmed),
              ["http", "https"].contains(link.scheme?.lowercased() ?? ""),
              let host = link.host?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be" || host == "www.youtu.be" else {
            status = "Enter a valid YouTube link."
            return
        }
        guard let downloader = executable("yt-dlp") else {
            status = "The app’s built-in downloader is missing. Reinstall the app."
            return
        }
        guard let ffmpeg = executable("ffmpeg"), executable("ffprobe") != nil else {
            status = "The app’s built-in media tools are missing. Reinstall the app."
            return
        }

        if format == 0, let id = videoID(from: link), let savedSource = existingSource(for: id) {
            log = "Reusing downloaded video: \(savedSource.lastPathComponent)\n"
            latestOutput = nil
            cancelled = false
            isDownloading = true
            convert(savedSource, preset: 0, quality: downloadQuality)
            return
        }

        let task = Process()
        task.executableURL = downloader
        var args = ["--newline", "--no-playlist", "--no-overwrites", "--paths", folder.path,
                    "--output", format == 0 ? "%(title).200B [%(id)s].%(ext)s" :
                        "%(title).200B [%(id)s] - MP3 \(audioBitrate)k.%(ext)s",
                    "--print", "after_move:CODEX_FILE:%(filepath)s",
                    "--ffmpeg-location", ffmpeg.deletingLastPathComponent().path]
        if format == 0 {
            args += ["-f", "bv*[vcodec^=avc1]+ba[acodec^=mp4a]/b[vcodec^=avc1][acodec^=mp4a]/bv*+ba/b", "--merge-output-format", "mp4", "--remux-video", "mp4"]
        } else {
            args += ["-x", "--audio-format", "mp3", "--audio-quality", "\(audioBitrate)K"]
        }
        args.append(trimmed)
        task.arguments = args
        task.environment = processEnvironment()

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        partialLine = ""
        log = ""
        progress = 0
        phase = "Downloading"
        downloadedFile = nil
        filesBeforeDownload = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
            .map { Set($0.map(\.standardizedFileURL.path)) }
        latestOutput = nil
        cancelled = false
        status = "Starting download…"
        isDownloading = true
        process = task

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.receive(chunk) }
        }
        task.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let tail = String(data: remainder, encoding: .utf8) { self.receive(tail + "\n") }
                self.isDownloading = false
                self.process = nil
                if self.cancelled {
                    self.phase = "Cancelled"
                    self.status = "Download cancelled."
                } else if finished.terminationStatus == 0 {
                    self.finishDownload()
                } else {
                    self.phase = "Error"
                    self.status = "Download failed. See details below."
                }
            }
        }
        do { try task.run() }
        catch {
            isDownloading = false
            process = nil
            status = "Could not start yt-dlp: \(error.localizedDescription)"
        }
    }

    func cancel() {
        cancelled = true
        guard let process, process.isRunning else { status = "Cancelling…"; return }
        process.terminate()
        status = "Cancelling…"
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.process === process, process.isRunning else { return }
            Darwin.kill(process.processIdentifier, SIGKILL)
        }
    }

    private func receive(_ chunk: String) {
        partialLine += chunk.replacingOccurrences(of: "\r", with: "\n")
        let lines = partialLine.components(separatedBy: "\n")
        partialLine = lines.last ?? ""
        for line in lines.dropLast() where !line.isEmpty {
            if line.hasPrefix("CODEX_FILE:") {
                downloadedFile = URL(fileURLWithPath: String(line.dropFirst("CODEX_FILE:".count)))
                continue
            }
            log += line + "\n"
            if log.count > 18000 { log = String(log.suffix(14000)) }
            if line.hasPrefix("[download]") {
                if let range = line.range(of: #"\d+(?:\.\d+)?%"#, options: .regularExpression),
                   let value = Double(line[range].dropLast()) {
                    progress = min(1, max(0, value / 100))
                    status = "Downloading… \(Int(value))%"
                } else {
                    status = "Downloading…"
                }
            } else if line.hasPrefix("[ExtractAudio]") || line.hasPrefix("[Merger]") || line.hasPrefix("[VideoRemuxer]") {
                status = line
            } else if line.hasPrefix("out_time_ms=") || line.hasPrefix("out_time_us=") {
                if let micros = Double(line.split(separator: "=").last ?? ""), duration > 0 {
                    progress = min(0.99, micros / 1_000_000 / duration)
                    status = "Converting for QuickTime… \(Int(progress * 100))%"
                }
            }
        }
    }

    private func finishDownload() {
        guard format == 0 else {
            let cachedFile = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap(videoID(from:)).flatMap { existingAudio(for: $0, bitrate: audioBitrate) }
            guard let file = [downloadedFile, cachedFile].compactMap({ $0 })
                .first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                phase = "Error"
                status = "Download finished, but its MP3 could not be found."
                return
            }
            progress = 1
            phase = "Complete"
            latestOutput = file
            status = "MP3 ready: \(file.lastPathComponent)"
            return
        }
        let cachedFile = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap(videoID(from:)).flatMap(existingSource(for:))
        guard let file = [downloadedFile, cachedFile].compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            phase = "Error"
            status = "Download finished, but its file could not be found."
            return
        }
        let sourceWasCreatedByThisDownload = downloadedFile?.standardizedFileURL == file.standardizedFileURL &&
            filesBeforeDownload?.contains(file.standardizedFileURL.path) == false
        convert(file, preset: 0, quality: downloadQuality,
                removeSourceOnSuccess: sourceWasCreatedByThisDownload)
    }

    private func videoID(from link: URL) -> String? {
        let host = link.host?.lowercased() ?? ""
        if host == "youtu.be" || host == "www.youtu.be" {
            return link.pathComponents.dropFirst().first
        }
        if let id = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
            return id
        }
        let parts = link.pathComponents
        if parts.count > 2 && ["shorts", "live", "embed"].contains(parts[1]) { return parts[2] }
        return nil
    }

    private func existingSource(for id: String) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        return files.first { $0.lastPathComponent.hasSuffix("[\(id)].mp4") && !$0.lastPathComponent.contains(" QuickTime") }
    }

    private var audioBitrate: Int { [128, 192, 320][min(max(audioQuality, 0), 2)] }

    private func existingAudio(for id: String, bitrate: Int) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        return files.first { $0.lastPathComponent.hasSuffix("[\(id)] - MP3 \(bitrate)k.mp3") }
    }

    private func convert(_ source: URL, preset: Int, quality: Int, removeSourceOnSuccess: Bool = false) {
        guard let ffmpeg = executable("ffmpeg"), let ffprobe = executable("ffprobe") else {
            isDownloading = false
            phase = "Error"
            status = "The app’s built-in media tools are missing. Reinstall the app."
            return
        }
        isDownloading = true
        phase = "Analyzing"
        status = "Checking the video…"
        progress = 0
        startProbe(source, using: ffprobe, ffmpeg: ffmpeg, preset: preset, quality: quality, removeSourceOnSuccess: removeSourceOnSuccess)
    }

    private func startProbe(_ source: URL, using ffprobe: URL, ffmpeg: URL, preset: Int, quality: Int, removeSourceOnSuccess: Bool) {
        let task = Process()
        task.executableURL = ffprobe
        task.arguments = ["-v", "error", "-show_entries", "stream=codec_type,codec_name,width,height:format=duration", "-of", "json", source.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch {
            isDownloading = false
            phase = "Error"
            status = "Could not analyze video: \(error.localizedDescription)"
            return
        }
        process = task
        Task.detached { [weak self] in
            let info = Self.readProbeOutput(from: task, pipe: pipe)
            await self?.completeProbe(info, source: source, ffmpeg: ffmpeg, preset: preset, quality: quality, removeSourceOnSuccess: removeSourceOnSuccess, probeProcess: task)
        }
    }

    private func completeProbe(_ info: (video: String?, audio: String?, duration: Double, width: Int, height: Int), source: URL, ffmpeg: URL, preset: Int, quality: Int, removeSourceOnSuccess: Bool, probeProcess: Process) {
        if process === probeProcess { process = nil }
        if cancelled {
            isDownloading = false
            phase = "Cancelled"
            status = "Conversion cancelled."
        } else if info.video == nil {
            isDownloading = false
            phase = "Error"
            status = "This file has no readable video track."
        } else {
            launchConversion(source, info: info, ffmpeg: ffmpeg, preset: preset, quality: quality, removeSourceOnSuccess: removeSourceOnSuccess)
        }
    }

    private func launchConversion(_ source: URL, info videoInfo: (video: String?, audio: String?, duration: Double, width: Int, height: Int), ffmpeg: URL, preset: Int, quality: Int, forceSoftware: Bool = false, removeSourceOnSuccess: Bool = false) {
        duration = videoInfo.duration
        let name = source.deletingPathExtension().lastPathComponent
        let presetName = ["H264", "HEVC", "ProRes"][min(max(preset, 0), 2)]
        let modeName = quality == 0 ? "Fast" : quality == 1 ? "Balanced" : "High Quality"
        let suffix = " - \(presetName) \(modeName)"
        let fileExtension = preset == 2 ? "mov" : "mp4"
        var output = source.deletingLastPathComponent().appendingPathComponent(name + suffix + "." + fileExtension)
        var number = 2
        while FileManager.default.fileExists(atPath: output.path) {
            output = source.deletingLastPathComponent().appendingPathComponent(name + suffix + " \(number)." + fileExtension)
            number += 1
        }
        let finalOutput = output
        phase = "Converting"
        status = forceSoftware ? "Hardware encoder unavailable; using fast software conversion…" : preset == 2 ? "Converting to ProRes…" : quality == 0 && preset == 0 ? "Using your Mac’s video encoder…" : "Converting for QuickTime…"
        progress = 0
        let task = Process()
        task.executableURL = ffmpeg
        var args = ["-hide_banner", "-loglevel", "error", "-progress", "pipe:1", "-i", source.path,
                    "-map", "0:v:0", "-map", "0:a:0?", "-sn", "-dn"]
        if preset == 0 && quality == 0 && !forceSoftware {
            let pixels = videoInfo.width * videoInfo.height
            let bitrate = pixels <= 1280 * 720 ? "3M" : pixels <= 1920 * 1080 ? "6M" : pixels <= 2560 * 1440 ? "10M" : "20M"
            args += ["-c:v", "h264_videotoolbox", "-b:v", bitrate, "-profile:v", "high", "-pix_fmt", "yuv420p"]
        } else if preset == 0 {
            args += ["-c:v", "libx264", "-preset", quality == 0 ? "ultrafast" : quality == 1 ? "veryfast" : "medium",
                     "-crf", quality == 0 ? "25" : quality == 1 ? "23" : "18", "-pix_fmt", "yuv420p"]
        } else if preset == 1 {
            args += ["-c:v", "libx265", "-preset", quality == 0 ? "ultrafast" : quality == 1 ? "fast" : "medium",
                     "-crf", quality == 0 ? "28" : quality == 1 ? "25" : "21", "-pix_fmt", "yuv420p", "-tag:v", "hvc1"]
        } else {
            args += ["-c:v", "prores_ks", "-profile:v", quality == 0 ? "1" : quality == 1 ? "2" : "3", "-pix_fmt", "yuv422p10le"]
        }
        if preset == 2 { args += ["-c:a", "pcm_s16le"] }
        else { args += ["-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"] }
        args.append(finalOutput.path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        partialLine = ""
        process = task
        isDownloading = true
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.receive(chunk) }
        }
        task.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let tail = String(data: remainder, encoding: .utf8) { self.receive(tail + "\n") }
                self.process = nil
                self.isDownloading = false
                if self.cancelled {
                    try? FileManager.default.removeItem(at: finalOutput)
                    self.phase = "Cancelled"
                    self.status = "Conversion cancelled."
                } else if finished.terminationStatus == 0 {
                    var sourceRemovalFailed = false
                    if removeSourceOnSuccess && source.standardizedFileURL != finalOutput.standardizedFileURL {
                        do { try FileManager.default.removeItem(at: source) }
                        catch {
                            sourceRemovalFailed = true
                            self.log += "Could not remove the temporary download: \(error.localizedDescription)\n"
                        }
                    }
                    self.progress = 1
                    self.phase = "Complete"
                    self.latestOutput = finalOutput
                    self.status = sourceRemovalFailed ?
                        "Video saved, but the original download could not be removed. See details." :
                        "QuickTime-ready video saved: \(finalOutput.lastPathComponent)"
                } else if preset == 0 && quality == 0 && !forceSoftware {
                    try? FileManager.default.removeItem(at: finalOutput)
                    self.log += "Hardware encoder unavailable. Retrying with libx264.\n"
                    self.launchConversion(source, info: videoInfo, ffmpeg: ffmpeg, preset: preset, quality: quality, forceSoftware: true, removeSourceOnSuccess: removeSourceOnSuccess)
                } else {
                    try? FileManager.default.removeItem(at: finalOutput)
                    self.phase = "Error"
                    self.status = "Conversion failed. See details below."
                }
            }
        }
        do { try task.run() } catch { process = nil; isDownloading = false; phase = "Error"; status = error.localizedDescription }
    }

    nonisolated private static func readProbeOutput(from task: Process, pipe: Pipe) -> (video: String?, audio: String?, duration: Double, width: Int, height: Int) {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return (nil, nil, 0, 0, 0) }
        guard let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return (nil, nil, 0, 0, 0) }
        let streams = info["streams"] as? [[String: Any]] ?? []
        let videoStream = streams.first { $0["codec_type"] as? String == "video" }
        let video = videoStream?["codec_name"] as? String
        let audio = streams.first { $0["codec_type"] as? String == "audio" }?["codec_name"] as? String
        let duration = Double((info["format"] as? [String: Any])?["duration"] as? String ?? "") ?? 0
        return (video, audio, duration, videoStream?["width"] as? Int ?? 0, videoStream?["height"] as? Int ?? 0)
    }

    private func executable(_ name: String) -> URL? {
        if name == "yt-dlp", FileManager.default.isExecutableFile(atPath: managedYTDLPURL.path) {
            return managedYTDLPURL
        }
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("Tools", isDirectory: true).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        }
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for directory in ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin"] + pathDirectories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let bundledTools = Bundle.main.resourceURL?.appendingPathComponent("Tools", isDirectory: true).path
        let preferredPaths = [managedToolsDirectory.path, bundledTools, "/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin", "/bin"]
            .compactMap { $0 }
        environment["PATH"] = (preferredPaths + [environment["PATH"] ?? ""]).joined(separator: ":")
        return environment
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @StateObject private var model = DownloadModel()
    private let releaseVersion = "2.6.1"
    private let isBetaRelease = true
    private let navy = Color(red: 0.09, green: 0.18, blue: 0.29)
    private var primaryText: Color { colorScheme == .dark ? .white : navy }
    private var glassBorder: Color { colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.55) }
    private var surfaceFill: Color { colorScheme == .dark ? Color(nsColor: .controlBackgroundColor).opacity(0.94) : .white.opacity(0.72) }
    private let coral = Color(red: 0.96, green: 0.32, blue: 0.25)
    private let orange = Color(red: 1.00, green: 0.56, blue: 0.16)
    private var accent: Color { colorScheme == .dark ? Color(red: 1.00, green: 0.48, blue: 0.31) : coral }

    var body: some View {
        ZStack {
            LinearGradient(colors: colorScheme == .dark ?
                           [Color(red: 0.13, green: 0.095, blue: 0.09), Color(red: 0.18, green: 0.115, blue: 0.10)] :
                           [Color(red: 1.00, green: 0.965, blue: 0.92), Color(red: 1.00, green: 0.91, blue: 0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            if !reduceTransparency {
                RadialGradient(colors: [orange.opacity(colorScheme == .dark ? 0.30 : 0.24), .clear], center: .topLeading, startRadius: 20, endRadius: 460)
                    .ignoresSafeArea().allowsHitTesting(false)
            }
            VStack(spacing: 0) {
                header
                tabBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if model.selectedTab == 0 { downloadTab }
                        else if model.selectedTab == 1 { converterTab }
                        else { settingsTab }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 12)
                }
                if model.selectedTab != 2 || model.isDownloading {
                    VStack(spacing: 12) {
                        statusCard
                        actionRow
                        details
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 560)
        .tint(accent)
        .onChange(of: model.selectedTab) { _, tab in
            guard !model.isDownloading && model.phase == "Ready" else { return }
            if tab == 0 { model.status = "Paste a YouTube link to get started." }
            else if tab == 1 {
                model.status = model.converterSource.map { "Ready to convert \($0.lastPathComponent)." } ?? "Choose a video to convert for QuickTime."
            }
        }
        .task { model.checkAutomaticallyIfNeeded() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AppMark()
            VStack(alignment: .leading, spacing: 4) {
                Text("YouTube Downloader").font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText).lineLimit(1).minimumScaleFactor(0.78)
                Text("Download and convert, ready for your Mac.").font(.system(size: 13))
                    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            Text(releaseVersion + (isBetaRelease ? " Beta" : ""))
                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(accent)
                .padding(.horizontal, 11).padding(.vertical, 7)
                .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 13)
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            tab("Download", icon: "arrow.down.to.line", value: 0)
            tab("QuickTime Converter", icon: "play.rectangle.on.rectangle", value: 1)
            tab("Settings", icon: "gearshape.fill", value: 2)
        }
        .padding(5)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 15))
        .padding(.horizontal, 26).padding(.bottom, 13)
    }

    private func tab(_ title: String, icon: String, value: Int) -> some View {
        Button { model.selectedTab = value } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(model.selectedTab == value ? primaryText : primaryText.opacity(0.65))
                .frame(maxWidth: .infinity).frame(height: 35)
                .background(model.selectedTab == value ? primaryText.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var downloadTab: some View {
        VStack(spacing: 16) {
            card(glassy: true) {
                VStack(alignment: .leading, spacing: 14) {
                    label("YOUTUBE LINK", icon: "link")
                    TextField("Paste a YouTube URL here", text: $model.url)
                        .textFieldStyle(.plain).font(.system(size: 15))
                        .padding(14)
                        .background(surfaceFill, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(glassBorder))
                        .onSubmit { if !model.isDownloading { model.start() } }
                        .disabled(model.isDownloading)
                    label("SAVE AS", icon: "square.stack")
                    HStack(spacing: 10) {
                        formatButton("Video", sub: "QuickTime MP4", icon: "play.rectangle.fill", value: 0)
                        formatButton("Audio", sub: "MP3 file", icon: "waveform", value: 1)
                    }
                    if model.format == 0 {
                        label("CONVERSION MODE", icon: "slider.horizontal.3")
                        Picker("Conversion mode", selection: $model.downloadQuality) {
                            Text("Fast · Hardware").tag(0)
                            Text("Balanced").tag(1)
                            Text("High Quality").tag(2)
                        }
                        .pickerStyle(.segmented).labelsHidden().disabled(model.isDownloading)
                        Text(downloadQualityDescription)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        label("MP3 QUALITY", icon: "waveform")
                        Picker("MP3 quality", selection: $model.audioQuality) {
                            Text("128 kbps").tag(0)
                            Text("192 kbps").tag(1)
                            Text("320 kbps").tag(2)
                        }
                        .pickerStyle(.segmented).labelsHidden().disabled(model.isDownloading)
                        Text(audioQualityDescription)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            card {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill").font(.system(size: 20)).foregroundStyle(accent).frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Save location").font(.system(size: 13, weight: .semibold)).foregroundStyle(primaryText)
                        Text(model.folder.path).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button("Change") { model.chooseFolder() }.disabled(model.isDownloading)
                }
            }
        }
    }

    private var converterTab: some View {
        VStack(spacing: 10) {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    label("SOURCE VIDEO", icon: "film")
                    HStack(spacing: 12) {
                        Image(systemName: "film.stack").font(.system(size: 21)).foregroundStyle(accent).frame(width: 30)
                        Text(model.converterSource?.lastPathComponent ?? "No video selected")
                            .font(.system(size: 13)).foregroundStyle(model.converterSource == nil ? .secondary : .primary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Choose Video") { model.chooseVideo() }.disabled(model.isDownloading)
                    }
                }
            }
            card(glassy: true) {
                VStack(alignment: .leading, spacing: 8) {
                    label("QUICKTIME OUTPUT", icon: "square.stack")
                    presetButton("H.264 MP4", description: "Best compatibility · moderate size", icon: "play.rectangle.fill", value: 0)
                    presetButton("HEVC MP4", description: "Potentially smaller · newer Macs", icon: "sparkles.tv", value: 1)
                    presetButton("ProRes MOV", description: "Editing quality · very large files", icon: "film.fill", value: 2)
                    label("QUALITY", icon: "slider.horizontal.3")
                    Picker("Quality", selection: $model.converterQuality) {
                        Text("Fast").tag(0)
                        Text("Balanced").tag(1)
                        Text("High Quality").tag(2)
                    }
                    .pickerStyle(.segmented).labelsHidden().disabled(model.isDownloading)
                    Text(conversionDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var settingsTab: some View {
        VStack(spacing: 12) {
            card(glassy: true) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(accent.opacity(0.14))
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(accent)
                        }.frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("yt-dlp Updater").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(primaryText)
                            Text("Keep the download engine current").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isCheckingForUpdates { ProgressView().controlSize(.small) }
                        else {
                            Label("Current", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(accent)
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(accent.opacity(0.11), in: Capsule())
                        }
                    }

                    Divider().opacity(0.35)

                    Toggle(isOn: $model.autoUpdateYTDLP) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Automatic updates")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(primaryText)
                            Text("Checks GitHub at most once every six hours")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack(spacing: 10) {
                        versionTile("INSTALLED", value: model.activeYTDLPVersion, icon: "shippingbox.fill")
                        versionTile("LATEST", value: model.latestYTDLPVersion ?? "Not checked", icon: "sparkles")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: model.updateStatus.contains("failed") ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(model.updateStatus.contains("failed") ? .orange : accent)
                        Text(model.updateStatus).font(.system(size: 11, weight: .medium)).foregroundStyle(primaryText.opacity(0.74))
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .background(accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 9) {
                        Button { model.checkForYTDLPUpdates() } label: {
                            Label("Check Now", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent).disabled(model.isCheckingForUpdates || model.isDownloading)
                        if model.hasManagedYTDLP {
                            Button("Restore Built-in") { model.restoreBundledYTDLP() }
                                .buttonStyle(.glass).disabled(model.isCheckingForUpdates || model.isDownloading)
                        }
                    }
                }
            }

            card {
                VStack(alignment: .leading, spacing: 11) {
                    label("SECURITY & STORAGE", icon: "checkmark.shield.fill")
                    settingsRow("Official source", detail: "yt-dlp_macos from GitHub", icon: "network")
                    settingsRow("Verified download", detail: "SHA-256 checked before install", icon: "checkmark.seal.fill")
                    settingsRow("Safe storage", detail: "The signed app stays unchanged", icon: "folder.badge.gearshape")
                    Divider().opacity(0.35)
                    HStack(spacing: 9) {
                        Image(systemName: "folder.fill").foregroundStyle(accent).frame(width: 22)
                        Text("Application Support / YouTube Downloader / Tools")
                            .font(.system(size: 10, design: .rounded)).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Show") { model.showManagedToolsFolder() }.controlSize(.small)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(accent).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media tools stay pinned").font(.system(size: 12, weight: .semibold)).foregroundStyle(primaryText)
                    Text("FFmpeg and FFprobe use the tested versions included with this app.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 15).padding(.vertical, 12)
            .background(surfaceFill.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(glassBorder))
        }
    }

    private func versionTile(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(accent).frame(width: 21)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(primaryText)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(10).frame(maxWidth: .infinity)
        .background(surfaceFill, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(glassBorder))
    }

    private func settingsRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent).frame(width: 22)
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(primaryText)
            Spacer()
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var statusCard: some View {
        card(glassy: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(model.phase.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(accent)
                    Spacer()
                    Text("\(Int(model.progress * 100))%").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                }
                Text(model.status).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(primaryText).lineLimit(2)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(primaryText.opacity(0.12))
                        Capsule().fill(accent).frame(width: max(0, geometry.size.width * model.progress))
                    }
                }.frame(height: 8)
            }
        }
    }

    private var actionRow: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
            Button(action: {
                if model.isDownloading { model.cancel() }
                else if model.selectedTab == 0 { model.start() }
                else { model.startConversion() }
            }) {
                Label(model.isDownloading ? "Cancel" : model.selectedTab == 0 ? "Download" : "Convert Video",
                      systemImage: model.isDownloading ? "xmark" : model.selectedTab == 0 ? "arrow.down.to.line" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .tint(model.isDownloading ? Color(red: 0.70, green: 0.32, blue: 0.35) : accent)
            Button(model.latestOutput == nil ? "Open Folder" : "Show Result") { model.openFolder() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryText)
                .frame(height: 40).padding(.horizontal, 16)
                .buttonStyle(.glass)
            }
        }
    }

    private var details: some View {
        DisclosureGroup("Details") {
            ScrollView {
                Text(model.log.isEmpty ? "Download and conversion messages will appear here." : model.log)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }.frame(height: 100)
        }
        .font(.system(size: 12)).padding(.horizontal, 4)
    }

    private func card<Content: View>(glassy: Bool = false, @ViewBuilder _ content: () -> Content) -> some View {
        Group {
            if glassy && !reduceTransparency {
                content().padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 19))
            } else {
                content().padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(surfaceFill, in: RoundedRectangle(cornerRadius: 19))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(glassBorder))
        .shadow(color: primaryText.opacity(0.06), radius: 12, y: 6)
    }

    private func label(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(primaryText.opacity(0.65))
    }

    private func formatButton(_ title: String, sub: String, icon: String, value: Int) -> some View {
        Button { model.format = value } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 19)).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(sub).font(.system(size: 11))
                }
                Spacer()
                if model.format == value { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundStyle(model.format == value ? accent : primaryText.opacity(0.7))
            .padding(12).frame(maxWidth: .infinity)
            .background(model.format == value ? accent.opacity(0.12) : surfaceFill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.format == value ? accent.opacity(0.40) : glassBorder))
        }.buttonStyle(.plain).disabled(model.isDownloading)
    }

    private func presetButton(_ title: String, description: String, icon: String, value: Int) -> some View {
        Button { model.converterPreset = value } label: {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 19)).frame(width: 27)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(description).font(.system(size: 11))
                }
                Spacer()
                if model.converterPreset == value { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundStyle(model.converterPreset == value ? accent : primaryText.opacity(0.7))
            .padding(6).frame(maxWidth: .infinity)
            .background(model.converterPreset == value ? accent.opacity(0.12) : surfaceFill, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(model.converterPreset == value ? accent.opacity(0.40) : glassBorder))
        }.buttonStyle(.plain).disabled(model.isDownloading)
    }

    private var conversionDescription: String {
        switch model.converterPreset {
        case 0:
            switch model.converterQuality {
            case 0: "Uses the Mac’s video hardware. Fastest and usually quieter."
            case 1: "Good quality with smaller files. Uses the CPU."
            default: "Keeps more detail. Slower and uses more CPU."
            }
        case 1:
            switch model.converterQuality {
            case 0: "HEVC can make smaller files, but even Fast uses the CPU."
            case 1: "Balances conversion time and file size."
            default: "Best detail at the slowest speed."
            }
        default:
            switch model.converterQuality {
            case 0: "ProRes LT: fast editing and large files."
            case 1: "ProRes 422: editing quality and larger files."
            default: "ProRes 422 HQ: maximum detail and very large files."
            }
        }
    }

    private var downloadQualityDescription: String {
        switch model.downloadQuality {
        case 0: "Uses the Mac’s video hardware when available. Fastest and usually quieter."
        case 1: "Uses the CPU for good quality and smaller files."
        default: "Uses the CPU to keep more detail. Slowest option."
        }
    }

    private var audioQualityDescription: String {
        switch model.audioQuality {
        case 0: "Smaller files for speech. Source audio may limit quality."
        case 1: "Balanced podcast audio and file size."
        default: "Largest MP3 files. Cannot improve low-quality source audio."
        }
    }
}

struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(red: 1.00, green: 0.62, blue: 0.18), Color(red: 0.96, green: 0.28, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 29)).foregroundStyle(.white)
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(red: 0.76, green: 0.18, blue: 0.12))
                .frame(width: 24, height: 24).background(.white, in: Circle()).offset(x: 22, y: 20)
        }.frame(width: 64, height: 64)
    }
}

@main
struct YouTubeDownloaderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .defaultSize(width: 560, height: 780)
    }
}
