import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @AppStorage("app.cineframe.settings.quickMode") private var quickMode = false
    @AppStorage("app.cineframe.settings.stripGPS") private var stripGPS = false
    @AppStorage("app.cineframe.settings.addCinematicKeyword") private var addKeyword = false
    @AppStorage("app.cineframe.settings.preserveFileDates") private var preserveDates = true
    @AppStorage("app.cineframe.settings.revealAfterExport") private var revealAfterExport = true

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }

            exportTab
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

            metadataTab
                .tabItem { Label("Metadata", systemImage: "tag") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(8)
        .frame(width: 600, height: 510)
        .onAppear {
            settings.quickMode = quickMode
            settings.stripGPS = stripGPS
            settings.addCinematicKeyword = addKeyword
            settings.preserveFileDates = preserveDates
            settings.revealAfterExport = revealAfterExport
        }
    }

    private var generalTab: some View {
        Form {
            Section("Behavior") {
                Toggle("Quick Mode", isOn: $quickMode)
                    .onChange(of: quickMode) { _, value in settings.quickMode = value }
                Text("Automatically export center crops when photos are dropped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Auto-crop") {
                Picker("Anchor", selection: $settings.cropAnchor) {
                    Text("Center").tag(CropAnchor.center)
                    Text("Smart (saliency)").tag(CropAnchor.smart)
                }
                Text("Quick Mode always uses Center.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Letterbox") {
                Picker("Bar color", selection: $settings.barColor) {
                    Text("Black").tag(BarColor.black)
                    Text("White").tag(BarColor.white)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding(14)
    }

    private var exportTab: some View {
        Form {
            Section("Destination") {
                Picker("Save to", selection: $settings.outputLocation) {
                    Text("Pictures/CineFrame").tag(OutputLocation.pictures)
                    Text("Next to original").tag(OutputLocation.nextToOriginal)
                    Text("Custom folder…").tag(OutputLocation.custom)
                }
                .onChange(of: settings.outputLocation) { _, value in
                    if value == .custom, FolderAccess.resolveBookmark(from: settings) == nil {
                        chooseCustomFolder()
                    }
                }

                if settings.outputLocation == .custom {
                    HStack(spacing: 10) {
                        Text(FolderAccess.resolveBookmark(from: settings)?.path ?? "No folder selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Button("Choose…", action: chooseCustomFolder)
                    }
                }
            }

            Section("File format") {
                TextField("File name suffix", text: $settings.outputSuffix)
                Picker("Format", selection: $settings.outputFormat) {
                    Text("Same as input").tag(OutputFormat.sameAsInput)
                    Text("JPEG").tag(OutputFormat.jpeg)
                    Text("HEIC").tag(OutputFormat.heic)
                    Text("PNG").tag(OutputFormat.png)
                    Text("TIFF").tag(OutputFormat.tiff)
                }

                if settings.outputFormat == .jpeg || settings.outputFormat == .heic || settings.outputFormat == .sameAsInput {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("JPEG / HEIC quality")
                            Spacer()
                            Text("\(Int(settings.lossyQuality * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.lossyQuality, in: 0.8...1, step: 0.01)
                            .accessibilityLabel("JPEG and HEIC quality")
                    }
                }
            }

            Section("After export") {
                Toggle("Reveal in Finder", isOn: $revealAfterExport)
                    .onChange(of: revealAfterExport) { _, value in settings.revealAfterExport = value }
            }

            Section("Performance") {
                Stepper("Concurrent exports: \(settings.maxConcurrentExports)",
                        value: $settings.maxConcurrentExports, in: 1...8)
            }
        }
        .formStyle(.grouped)
        .padding(14)
    }

    private var metadataTab: some View {
        Form {
            Section("Privacy") {
                Toggle("Strip GPS location", isOn: $stripGPS)
                    .onChange(of: stripGPS) { _, value in settings.stripGPS = value }
                Text("Remove GPS coordinates from exported photos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Export details") {
                Toggle("Add ‘Cinematic’ keyword", isOn: $addKeyword)
                    .onChange(of: addKeyword) { _, value in settings.addCinematicKeyword = value }
                Toggle("Preserve file dates", isOn: $preserveDates)
                    .onChange(of: preserveDates) { _, value in settings.preserveFileDates = value }
            }
        }
        .formStyle(.grouped)
        .padding(14)
    }

    private var aboutTab: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 12)

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("Cine Frame")
                    .font(.system(size: 24, weight: .semibold))
                Text("Version \(appVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Prepare cinematic crops with precise letterboxing.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(maxWidth: 300)
                .padding(.vertical, 4)

            Text("Made by @tarudesu")
                .font(.callout.weight(.medium))

            Text("Enjoying Cine Frame? Support its development with a bánh mì.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            if let donateURL = URL(string: "https://buy-me-a-banhmi.vercel.app/#donate") {
                Link(destination: donateURL) {
                    Label("Mời mình bánh mì", systemImage: "heart.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("25.000đ per bánh mì · VietQR. Confirmed donation details appear on the public gratitude board.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0"
        if let build = info["CFBundleVersion"] as? String, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }

    private func chooseCustomFolder() {
        guard let folder = FolderAccess.chooseFolder(message: "Choose an output folder") else { return }
        do {
            try FolderAccess.saveBookmark(for: folder, settings: settings)
            settings.outputLocation = .custom
        } catch {
            settings.outputLocation = .pictures
        }
    }
}
