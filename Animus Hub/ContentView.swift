import SwiftUI
import AppKit

struct ContentView: View {

    private let scriptsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Proyectos/Animus/Scripts")

    @State private var scripts: [String] = []
    @State private var selectedScript: String?
    @State private var versions: [String: String] = [:]
    @State private var gitStates: [String: GitState] = [:]

    private struct AnimusApplication: Identifiable {
        let name: String
        let icon: String

        var id: String { name }
    }

    private let applications: [AnimusApplication] = [
        .init(name: "Animus Hub", icon: "AnimusHub"),
        .init(name: "Animus Music", icon: "AnimusMusic"),
        .init(name: "Animus Download", icon: "AnimusDownload"),
        .init(name: "Animus Video", icon: "AnimusVideo")
    ]

    private var applicationsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Documents/Proyectos/Animus/Apps"
            )
    }

    @State private var selectedApplication: String?
    @State private var applicationVersions: [String: String] = [:]

    @State private var updateStates: [String: ApplicationUpdateState] = [:]

    private enum ApplicationUpdateState {
        case checking
        case current(String)
        case available(String)
        case unpublished
        case notInstalled
        case failed

        var title: String {
            switch self {
            case .checking:
                return "Comprobando…"
            case .current(let version):
                return "Actualizada · v\(version)"
            case .available(let version):
                return "Actualización disponible · v\(version)"
            case .unpublished:
                return "Sin publicaciones"
            case .notInstalled:
                return "Aplicación no instalada"
            case .failed:
                return "Error al comprobar"
            }
        }

        var symbol: String {
            switch self {
            case .checking:
                return "arrow.clockwise"
            case .current:
                return "checkmark.circle.fill"
            case .available:
                return "arrow.down.circle.fill"
            case .unpublished:
                return "minus.circle.fill"
            case .notInstalled:
                return "questionmark.circle.fill"
            case .failed:
                return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .checking, .unpublished, .notInstalled:
                return .gray
            case .current:
                return .green
            case .available:
                return .orange
            case .failed:
                return .red
            }
        }
    }


    private struct GitState {
        var branch = "Desconocida"
        var hasChanges = false
        var ahead = 0
        var behind = 0
        var hasUpstream = false
        var error: String?

        var title: String {
            if error != nil {
                return "No disponible"
            }
            if hasChanges {
                return "Cambios locales pendientes"
            }
            if !hasUpstream {
                return "Sin seguimiento remoto"
            }
            if ahead > 0 && behind > 0 {
                return "Ramas divergentes"
            }
            if ahead > 0 {
                return "Commits pendientes de subir"
            }
            if behind > 0 {
                return "Commits pendientes de integrar"
            }
            return "Proyecto actualizado"
        }

        var symbol: String {
            if error != nil { return "questionmark.circle.fill" }
            if hasChanges { return "circle.fill" }
            if !hasUpstream { return "questionmark.circle.fill" }
            if ahead > 0 && behind > 0 {
                return "arrow.left.arrow.right.circle.fill"
            }
            if ahead > 0 { return "arrow.up.circle.fill" }
            if behind > 0 { return "arrow.down.circle.fill" }
            return "checkmark.circle.fill"
        }

        var color: Color {
            if error != nil { return .gray }
            if hasChanges { return .orange }
            if !hasUpstream { return .gray }
            if ahead > 0 && behind > 0 { return .red }
            if ahead > 0 { return .blue }
            if behind > 0 { return .purple }
            return .green
        }
    }

    var body: some View {
        NavigationSplitView {
            List {
                Section("SCRIPTS") {
                    ForEach(scripts, id: \.self) { script in
                        HStack(spacing: 8) {
                            Label(script, systemImage: "terminal")

                            Spacer(minLength: 4)

                            if let state = gitStates[script] {
                                Image(systemName: state.symbol)
                                    .font(.system(size: 9))
                                    .foregroundStyle(state.color)
                                    .help(state.title)
                            }

                            Text(versions[script] ?? "—")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedScript = script
                            selectedApplication = nil
                        }
                        .listRowBackground(
                            selectedScript == script
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                    }
                }

                Section {
                    ForEach(applications) { application in
                        HStack(spacing: 8) {
                            applicationIcon(application.name, size: 17)

                            Text(application.name)

                            Spacer(minLength: 4)

                            if let state = updateStates[application.name] {
                                Image(systemName: state.symbol)
                                    .font(.system(size: 10))
                                    .foregroundStyle(state.color)
                                    .help(state.title)
                            }

                            Text(
                                applicationVersions[application.name]
                                    ?? "No instalada"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedApplication = application.name
                            selectedScript = nil
                        }
                        .listRowBackground(
                            selectedApplication == application.name
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()
                        Text("APLICACIONES")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Animus Hub")
            .navigationSplitViewColumnWidth(
                min: 240,
                ideal: 290,
                max: 420
            )
        } detail: {
            if let selectedApplication {
                applicationDetail(selectedApplication)
            } else if let selectedScript {
                projectDetail(selectedScript)
            } else {
                welcomeView
            }
        }
        .frame(minWidth: 850, minHeight: 550)
        .toolbar {
            Button {
                loadScripts()
                loadApplications()
                checkApplicationUpdates()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Actualizar información")
        }
        .task {
            loadScripts()
            loadApplications()
            checkApplicationUpdates()
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Animus Hub")
                .font(.largeTitle.bold())

            Text("\(scripts.count) proyectos detectados")
                .foregroundStyle(.secondary)

            Text("Selecciona un proyecto para ver sus detalles")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectDetail(_ script: String) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text(script)
                    .font(.largeTitle.bold())

                Text("Versión \(versions[script] ?? "desconocida")")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Divider()

                if let state = gitStates[script] {
                    VStack(spacing: 14) {
                        Text("ESTADO DE GIT")
                            .font(.headline)

                        Label(state.title, systemImage: state.symbol)
                            .font(.title3)
                            .foregroundStyle(state.color)

                        VStack(alignment: .leading, spacing: 10) {
                            detailRow("Rama", state.branch)

                            detailRow(
                                "Cambios locales",
                                state.hasChanges ? "Sí" : "Ninguno"
                            )

                            if state.hasUpstream {
                                detailRow(
                                    "Commits por subir",
                                    "\(state.ahead)"
                                )

                                detailRow(
                                    "Commits por integrar",
                                    "\(state.behind)"
                                )
                            } else {
                                detailRow(
                                    "Seguimiento remoto",
                                    "No configurado"
                                )
                            }

                            if let error = state.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: 360)
                    }
                }

                Divider()

                Text("Ubicación del proyecto")
                    .font(.headline)

                Button {
                    let folder = scriptsPath.appendingPathComponent(script)
                    NSWorkspace.shared.open(folder)
                } label: {
                    Label("Abrir en Finder", systemImage: "folder")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .help("Abrir la carpeta del proyecto en Finder")
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }

    private func applicationURL(_ name: String) -> URL {
        applicationsPath
            .appendingPathComponent(name)
            .appendingPathComponent(
                "_Build/Build/Products/Release/\(name).app"
            )
    }

    private func applicationIcon(
        _ name: String,
        size: CGFloat
    ) -> some View {
        let icons: [String: String] = [
            "Animus Hub": "AnimusHub",
            "Animus Music": "AnimusMusic",
            "Animus Download": "AnimusDownload",
            "Animus Video": "AnimusVideo"
        ]

        let appURL = applicationURL(name)

        let iconURL = appURL
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent(
                "\(icons[name] ?? "AnimusHub").icns"
            )

        let icon = NSImage(contentsOf: iconURL)
            ?? NSWorkspace.shared.icon(forFile: appURL.path)

        return Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func loadApplications() {
        var result: [String: String] = [:]

        for application in applications {
            let appURL = applicationURL(application.name)

            let plistURL = appURL
                .appendingPathComponent("Contents/Info.plist")

            guard
                let info = NSDictionary(
                    contentsOf: plistURL
                ),
                let version = info[
                    "CFBundleShortVersionString"
                ] as? String
            else {
                continue
            }

            result[application.name] = "v\(version)"
        }

        applicationVersions = result
    }


    private func checkApplicationUpdates() {
        for application in applications {
            let name = application.name
            let plistURL = applicationURL(name)
                .appendingPathComponent("Contents/Info.plist")

            guard
                let info = NSDictionary(contentsOf: plistURL),
                let installedBuild = info["CFBundleVersion"] as? String,
                let localBuild = Int(installedBuild),
                let feed = info["SUFeedURL"] as? String,
                let url = URL(string: feed)
            else {
                updateStates[name] = .notInstalled
                continue
            }

            updateStates[name] = .checking

            Task {
                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 15
                    request.cachePolicy = .reloadIgnoringLocalCacheData

                    let (data, response) = try await URLSession.shared.data(
                        for: request
                    )

                    guard
                        let http = response as? HTTPURLResponse,
                        http.statusCode == 200
                    else {
                        updateStates[name] = .failed
                        return
                    }

                    let reader = AnimusAppcastReader(data: data)

                    guard reader.parse() else {
                        updateStates[name] = .failed
                        return
                    }

                    if reader.releases.isEmpty {
                        updateStates[name] = .unpublished
                        return
                    }

                    guard let latest = reader.releases.max(
                        by: { $0.build < $1.build }
                    ) else {
                        updateStates[name] = .failed
                        return
                    }

                    if latest.build > localBuild {
                        updateStates[name] = .available(latest.version)
                    } else {
                        updateStates[name] = .current(latest.version)
                    }

                } catch {
                    updateStates[name] = .failed
                }
            }
        }
    }

    private func applicationDetail(_ name: String) -> some View {
        let url = applicationURL(name)
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let info = NSDictionary(contentsOf: plistURL)

        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        let installed = version != nil

        return ScrollView {
            VStack(spacing: 24) {

                applicationIcon(name, size: 90)

                Text(name)
                    .font(.largeTitle.bold())

                VStack(spacing: 14) {
                    detailRow(
                        "Versión instalada",
                        version ?? "No instalada"
                    )

                    detailRow(
                        "Compilación",
                        build ?? "—"
                    )

                    Divider()

                    if let state = updateStates[name] {
                        switch state {
                        case .current(let published):
                            detailRow(
                                "Última versión publicada",
                                published
                            )

                        case .available(let published):
                            detailRow(
                                "Nueva versión disponible",
                                published
                            )

                        case .unpublished:
                            detailRow(
                                "Última versión publicada",
                                "Sin publicaciones"
                            )

                        case .checking:
                            detailRow(
                                "Última versión publicada",
                                "Comprobando…"
                            )

                        case .failed:
                            detailRow(
                                "Última versión publicada",
                                "No disponible"
                            )

                        case .notInstalled:
                            detailRow(
                                "Última versión publicada",
                                "—"
                            )
                        }

                        HStack {
                            Text("Estado")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Label(
                                state.title,
                                systemImage: state.symbol
                            )
                            .foregroundStyle(state.color)
                        }
                    } else {
                        detailRow(
                            "Estado",
                            "Sin comprobar"
                        )
                    }
                }
                .padding(20)
                .frame(maxWidth: 440)
                .background(
                    .quaternary.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14)
                )

                VStack(spacing: 12) {

                    if installed {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label(
                                "Abrir aplicación",
                                systemImage: "arrow.up.right.square"
                            )
                            .frame(minWidth: 220)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            checkApplicationUpdates()
                        } label: {
                            Label(
                                "Buscar actualizaciones",
                                systemImage: "arrow.clockwise"
                            )
                            .frame(minWidth: 220)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        NSWorkspace.shared.open(
                            installed
                                ? url.deletingLastPathComponent()
                                : applicationsPath.appendingPathComponent(name)
                        )
                    } label: {
                        Label(
                            "Mostrar en Finder",
                            systemImage: "folder"
                        )
                        .frame(minWidth: 220)
                    }
                    .buttonStyle(.bordered)
                }

                if case .available = updateStates[name] {
                    Text(
                        "Abre la aplicación para instalar la actualización mediante Sparkle."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    private func loadScripts() {
        do {
            let folders = try FileManager.default.contentsOfDirectory(
                at: scriptsPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            scripts = folders
                .filter {
                    (try? $0.resourceValues(
                        forKeys: [.isDirectoryKey]
                    ).isDirectory) == true
                }
                .map(\.lastPathComponent)
                .sorted()

            versions = [:]
            gitStates = [:]

            for script in scripts {
                let path = scriptsPath.appendingPathComponent(script)

                versions[script] = git(
                    ["describe", "--tags", "--abbrev=0"],
                    at: path
                ) ?? "Sin versión"

                gitStates[script] = readGitState(at: path)
            }

        } catch {
            print("Error al leer los scripts: \(error)")
        }
    }

    private func readGitState(at path: URL) -> GitState {
        var state = GitState()

        guard let branch = git(
            ["branch", "--show-current"],
            at: path
        ) else {
            state.error = "No se ha podido consultar Git."
            return state
        }

        state.branch = branch.isEmpty ? "HEAD separado" : branch

        guard let status = git(
            ["status", "--porcelain", "--untracked-files=normal"],
            at: path
        ) else {
            state.error = "No se ha podido consultar el estado."
            return state
        }

        state.hasChanges = !status.isEmpty

        if git(
            [
                "rev-parse",
                "--abbrev-ref",
                "--symbolic-full-name",
                "@{upstream}"
            ],
            at: path
        ) != nil {
            state.hasUpstream = true

            if let counts = git(
                [
                    "rev-list",
                    "--left-right",
                    "--count",
                    "@{upstream}...HEAD"
                ],
                at: path
            ) {
                let numbers = counts
                    .split(whereSeparator: \.isWhitespace)
                    .compactMap { Int($0) }

                if numbers.count == 2 {
                    state.behind = numbers[0]
                    state.ahead = numbers[1]
                } else {
                    state.error = "No se pudieron interpretar los commits."
                }
            } else {
                state.error = "No se pudieron comparar las ramas."
            }
        }

        return state
    }

    private func git(_ arguments: [String], at path: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path.path] + arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()

            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  let result = String(data: data, encoding: .utf8) else {
                return nil
            }

            return result.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        } catch {
            return nil
        }
    }
}

#Preview {
    ContentView()
}


private final class AnimusAppcastReader: NSObject, XMLParserDelegate {
    struct Release {
        let version: String
        let build: Int
    }

    private let xmlParser: XMLParser
    private(set) var releases: [Release] = []

    private var insideItem = false
    private var currentElement = ""
    private var currentVersion = ""
    private var currentBuild = ""
    private var buffer = ""

    init(data: Data) {
        xmlParser = XMLParser(data: data)
        super.init()
        xmlParser.delegate = self
    }

    func parse() -> Bool {
        xmlParser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.split(separator: ":").last.map(String.init)
            ?? elementName

        currentElement = name
        buffer = ""

        if name == "item" {
            insideItem = true
            currentVersion = ""
            currentBuild = ""
        }

        if insideItem && name == "enclosure" {
            if currentVersion.isEmpty {
                currentVersion = attributeDict[
                    "sparkle:shortVersionString"
                ] ?? ""
            }

            if currentBuild.isEmpty {
                currentBuild = attributeDict["sparkle:version"] ?? ""
            }
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.split(separator: ":").last.map(String.init)
            ?? elementName

        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if insideItem {
            if name == "shortVersionString" {
                currentVersion = value
            } else if name == "version" {
                currentBuild = value
            } else if name == "item" {
                if let build = Int(currentBuild),
                   !currentVersion.isEmpty {
                    releases.append(
                        Release(
                            version: currentVersion,
                            build: build
                        )
                    )
                }
                insideItem = false
            }
        }

        buffer = ""
    }
}
