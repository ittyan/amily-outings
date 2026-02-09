import SwiftUI
import MapKit
import CoreLocation
import AuthenticationServices

// MARK: - Data Model
struct SpotDTO: Codable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let address: String
    let summary: String
    let official_url: String?
    let cost_range: String?
    let age_min: Int?
    let age_max: Int?
    let tags: [String]
    let images: [String]
    let hours: String?
}

struct Spot: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
    let description: String
    let url: String?
    let priceRange: PriceRange?
    let ageMin: Int?
    let ageMax: Int?
    let tags: [String]
    let source: String
    let lastUpdated: Date

    init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String,
        description: String,
        url: String? = nil,
        priceRange: PriceRange? = nil,
        ageMin: Int? = nil,
        ageMax: Int? = nil,
        tags: [String] = [],
        source: String,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.description = description
        self.url = url
        self.priceRange = priceRange
        self.ageMin = ageMin
        self.ageMax = ageMax
        self.tags = tags
        self.source = source
        self.lastUpdated = lastUpdated
    }
}

enum PriceRange: String, CaseIterable, Codable {
    case free = "FREE"
    case u500 = "U500"
    case u1000 = "U1000"
    case u3000 = "U3000"
    case over3000 = "OVER3000"

    var label: String {
        switch self {
        case .free: return "無料"
        case .u500: return "〜500円"
        case .u1000: return "〜1000円"
        case .u3000: return "〜3000円"
        case .over3000: return "3000円以上"
        }
    }
}

enum DataFetchStatus {
    case idle
    case fetching
    case success
    case error(String)
}

extension PriceRange {
    init?(apiValue: String?) {
        guard let apiValue else { return nil }
        self.init(rawValue: apiValue)
    }
}

extension Spot {
    init(dto: SpotDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            latitude: dto.lat,
            longitude: dto.lng,
            address: dto.address,
            description: dto.summary,
            url: dto.official_url,
            priceRange: PriceRange(apiValue: dto.cost_range),
            ageMin: dto.age_min,
            ageMax: dto.age_max,
            tags: dto.tags,
            source: "API",
            lastUpdated: Date()
        )
    }
}

// MARK: - Location Manager
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep last known region
    }
}

// MARK: - Spot Data Service (Mock)
final class SpotDataService: ObservableObject {
    @Published var spots: [Spot] = []

    func fetchSpots(in region: MKCoordinateRegion, filters: SpotFilters, searchText: String) {
        Task {
            await fetchSpotsAsync(in: region, filters: filters, searchText: searchText)
        }
    }

    @MainActor
    private func fetchSpotsAsync(in region: MKCoordinateRegion, filters: SpotFilters, searchText: String) async {
        do {
            let dtos = try await APIClient.shared.fetchSpots(
                lat: region.center.latitude,
                lng: region.center.longitude,
                radiusKm: 5.0,
                filters: filters,
                searchText: searchText
            )
            spots = dtos.map { Spot(dto: $0) }
        } catch {
            // Keep last known spots on error
        }
    }
}

// MARK: - Data Fetch Service
final class DataFetchService: ObservableObject {
    @Published var status: DataFetchStatus = .idle

    func fetchAllData() {
        status = .fetching
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.status = .success
        }
    }
}

// MARK: - Admin Auth
final class AdminAuthManager: ObservableObject {
    @Published var isAdmin = false
    @Published var isAuthenticating = false

    func authenticate(password: String) {
        isAuthenticating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if password == "password" {
                self.isAdmin = true
            }
            self.isAuthenticating = false
        }
    }
}

// MARK: - User Auth (Placeholder)
final class UserAuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var userId: String? = nil
    @Published var sessionToken: String? = nil

    private let guestKey = "guest_user_id"

    func ensureUserId() {
        if let existing = UserDefaults.standard.string(forKey: guestKey) {
            userId = existing
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: guestKey)
            userId = newId
        }
    }

    func signInAsGuest() {
        ensureUserId()
        isLoggedIn = true
    }

    func signOut() {
        isLoggedIn = false
        sessionToken = nil
    }
}

// MARK: - Favorites
final class DataManager: ObservableObject {
    @Published private(set) var favorites: Set<String> = []
    @Published var isSyncing = false

    func loadFavorites(userId: String) {
        Task { await loadFavoritesAsync(userId: userId) }
    }

    func toggleFavorite(_ spotId: String, userId: String) {
        Task { await toggleFavoriteAsync(spotId, userId: userId) }
    }

    func isFavorite(_ spotId: String) -> Bool {
        favorites.contains(spotId)
    }

    @MainActor
    private func loadFavoritesAsync(userId: String) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let items = try await APIClient.shared.fetchFavorites(userId: userId)
            favorites = Set(items.map { $0.id })
        } catch {
            // Keep last known favorites on error
        }
    }

    @MainActor
    private func toggleFavoriteAsync(_ spotId: String, userId: String) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            if favorites.contains(spotId) {
                try await APIClient.shared.removeFavorite(userId: userId, spotId: spotId)
                favorites.remove(spotId)
            } else {
                try await APIClient.shared.addFavorite(userId: userId, spotId: spotId)
                favorites.insert(spotId)
            }
        } catch {
            // Keep last known favorites on error
        }
    }
}

// MARK: - Filters
struct SpotFilters {
    var selectedPrice: PriceRange? = nil
    var selectedAge: Int? = nil
    var selectedTags: Set<String> = []
}

// MARK: - List Items (with Ads)
enum ListItem: Identifiable {
    case spot(Spot)
    case ad(UUID)

    var id: String {
        switch self {
        case .spot(let spot): return "spot-\(spot.id)"
        case .ad(let uuid): return "ad-\(uuid.uuidString)"
        }
    }
}

// MARK: - Map View
struct SpotMapView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var spotDataService: SpotDataService
    @Binding var selectedSpot: Spot?

    @State private var cameraPosition: MapCameraPosition

    init(
        locationManager: LocationManager,
        spotDataService: SpotDataService,
        selectedSpot: Binding<Spot?>
    ) {
        self.locationManager = locationManager
        self.spotDataService = spotDataService
        self._selectedSpot = selectedSpot
        self._cameraPosition = State(initialValue: .region(locationManager.region))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(spotDataService.spots) { spot in
                Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .onTapGesture { selectedSpot = spot }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(locationManager.$region) { newRegion in
            cameraPosition = .region(newRegion)
        }
    }
}

// MARK: - List View
struct SpotListView: View {
    let items: [ListItem]
    let onSelect: (Spot) -> Void

    var body: some View {
        List(items) { item in
            switch item {
            case .spot(let spot):
                Button(action: { onSelect(spot) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(spot.name).font(.headline)
                        Text(spot.address).font(.subheadline).foregroundColor(.secondary)
                        if let price = spot.priceRange {
                            Text("料金: \(price.label)").font(.caption)
                        }
                    }
                }
            case .ad:
                AdBannerView()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Detail View
struct SpotDetailView: View {
    let spot: Spot
    @ObservedObject var dataManager: DataManager
    let userId: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(spot.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(spot.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(spot.description)

                if let url = spot.url, let link = URL(string: url) {
                    Link("詳細情報", destination: link)
                        .font(.subheadline)
                }

                if let price = spot.priceRange {
                    Text("料金: \(price.label)")
                        .font(.subheadline)
                }

                if let min = spot.ageMin, let max = spot.ageMax {
                    Text("対象年齢: \(min)〜\(max)歳")
                        .font(.subheadline)
                }

                if !spot.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(spot.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                Text("情報提供: \(spot.source)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Button(action: {
                        dataManager.toggleFavorite(spot.id, userId: userId)
                    }) {
                        HStack {
                            Image(systemName: dataManager.isFavorite(spot.id) ? "heart.fill" : "heart")
                                .foregroundColor(dataManager.isFavorite(spot.id) ? .red : .gray)
                            Text(dataManager.isFavorite(spot.id) ? "お気に入り済み" : "お気に入りに追加")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    Button(action: { openInMaps(spot) }) {
                        HStack {
                            Image(systemName: "map")
                            Text("経路")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openInMaps(_ spot: Spot) {
        let lat = spot.latitude
        let lng = spot.longitude
        let encodedName = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)&q=\(encodedName)") {
            openURL(url)
        }
    }
}

// MARK: - Admin Panel
struct AdminPanelView: View {
    @ObservedObject var adminAuth: AdminAuthManager
    @ObservedObject var dataFetchService: DataFetchService

    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("管理者")
                .font(.title2)

            if !adminAuth.isAdmin {
                SecureField("管理者パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("認証") {
                    adminAuth.authenticate(password: password)
                }
                .disabled(adminAuth.isAuthenticating)

                if adminAuth.isAuthenticating { ProgressView() }
            } else {
                Button(action: { dataFetchService.fetchAllData() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("データ更新")
                    }
                }
                .disabled(dataFetchService.status == .fetching)

                if case .fetching = dataFetchService.status {
                    ProgressView("データ取得中...")
                } else if case .error(let message) = dataFetchService.status {
                    Text(message).foregroundColor(.red)
                }
            }
        }
        .padding()
    }
}

// MARK: - Filters View
struct FiltersView: View {
    @Binding var filters: SpotFilters

    private let allTags = ["屋内", "屋外", "雨でもOK", "ベビーカーOK", "授乳室", "駐車場"]

    var body: some View {
        Form {
            Section(header: Text("料金")) {
                Picker("料金", selection: $filters.selectedPrice) {
                    Text("指定なし").tag(PriceRange?.none)
                    ForEach(PriceRange.allCases, id: \.self) { price in
                        Text(price.label).tag(PriceRange?.some(price))
                    }
                }
            }

            Section(header: Text("対象年齢")) {
                Picker("年齢", selection: $filters.selectedAge) {
                    Text("指定なし").tag(Int?.none)
                    ForEach(0..<18, id: \.self) { age in
                        Text("\(age)歳").tag(Int?.some(age))
                    }
                }
            }

            Section(header: Text("タグ")) {
                ForEach(allTags, id: \.self) { tag in
                    Toggle(tag, isOn: Binding(
                        get: { filters.selectedTags.contains(tag) },
                        set: { isOn in
                            if isOn { filters.selectedTags.insert(tag) }
                            else { filters.selectedTags.remove(tag) }
                        }
                    ))
                }
            }
        }
    }
}

// MARK: - User Login View
struct UserLoginView: View {
    @ObservedObject var auth: UserAuthManager

    var body: some View {
        VStack(spacing: 24) {
            Text("ログイン")
                .font(.title2)

            SignInWithAppleButton(.signIn, onRequest: { _ in
                // TODO: Implement Apple Sign-In
            }, onCompletion: { _ in
                auth.ensureUserId()
                auth.isLoggedIn = true
            })
            .frame(height: 44)

            Button("ゲストとして続行") {
                auth.signInAsGuest()
            }
        }
        .padding()
    }
}

// MARK: - Ad Placeholder
struct AdBannerView: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 60)
            .overlay(Text("Ad"))
    }
}

// MARK: - Main Content
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var spotDataService = SpotDataService()
    @StateObject private var dataFetchService = DataFetchService()
    @StateObject private var adminAuth = AdminAuthManager()
    @StateObject private var dataManager = DataManager()
    @StateObject private var userAuth = UserAuthManager()

    @State private var selectedSpot: Spot?
    @State private var viewMode: Int = 0 // 0 map, 1 list
    @State private var showFilters = false
    @State private var filters = SpotFilters()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            if !userAuth.isLoggedIn {
                UserLoginView(auth: userAuth)
            } else {
                VStack(spacing: 0) {
                    Picker("表示", selection: $viewMode) {
                        Text("マップ").tag(0)
                        Text("一覧").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if viewMode == 0 {
                        SpotMapView(
                            locationManager: locationManager,
                            spotDataService: spotDataService,
                            selectedSpot: $selectedSpot
                        )
                    } else {
                        SpotListView(items: listItems) { spot in
                            selectedSpot = spot
                        }
                    }

                    if let spot = selectedSpot {
                        NavigationLink(destination: SpotDetailView(spot: spot, dataManager: dataManager, userId: userAuth.userId ?? \"\")) {
                            Text("詳細を見る")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }

                    AdBannerView()
                        .padding(.top, 8)
                }
                .navigationTitle("地図")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("フィルタ") { showFilters = true }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink("管理者") {
                            AdminPanelView(adminAuth: adminAuth, dataFetchService: dataFetchService)
                        }
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
                .onAppear {
                    locationManager.requestLocation()
                    spotDataService.fetchSpots(in: locationManager.region, filters: filters, searchText: searchText)
                }
                .onChange(of: locationManager.region) { newRegion in
                    spotDataService.fetchSpots(in: newRegion, filters: filters, searchText: searchText)
                }
                .onChange(of: filters.selectedPrice) { _ in
                    spotDataService.fetchSpots(in: locationManager.region, filters: filters, searchText: searchText)
                }
                .onChange(of: filters.selectedAge) { _ in
                    spotDataService.fetchSpots(in: locationManager.region, filters: filters, searchText: searchText)
                }
                .onChange(of: filters.selectedTags) { _ in
                    spotDataService.fetchSpots(in: locationManager.region, filters: filters, searchText: searchText)
                }
                .onChange(of: searchText) { _ in
                    spotDataService.fetchSpots(in: locationManager.region, filters: filters, searchText: searchText)
                }
                .onChange(of: userAuth.isLoggedIn) { loggedIn in
                    if loggedIn, let userId = userAuth.userId {
                        dataManager.loadFavorites(userId: userId)
                    }
                }
                .sheet(isPresented: $showFilters) {
                    FiltersView(filters: $filters)
                }
            }
        }
    }

    private var filteredSpots: [Spot] {
        spotDataService.spots.filter { spot in
            if let price = filters.selectedPrice, spot.priceRange != price { return false }
            if let age = filters.selectedAge {
                if let min = spot.ageMin, let max = spot.ageMax {
                    if age < min || age > max { return false }
                }
            }
            if !filters.selectedTags.isEmpty {
                if filters.selectedTags.isDisjoint(with: Set(spot.tags)) { return false }
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let haystack = [spot.name, spot.address, spot.description, spot.tags.joined(separator: " ")].joined(separator: " ").lowercased()
                if !haystack.contains(q) { return false }
            }
            return true
        }
    }

    private var listItems: [ListItem] {
        var items: [ListItem] = []
        let insertEvery = 4
        for (idx, spot) in filteredSpots.enumerated() {
            items.append(.spot(spot))
            if (idx + 1) % insertEvery == 0 {
                items.append(.ad(UUID()))
            }
        }
        return items
    }
}

// MARK: - App
@main
struct FamilyOutingsApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - API Client
struct FavoritesResponseDTO: Codable {
    let items: [SpotDTO]
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "http://localhost:8000")!
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    func fetchSpots(lat: Double, lng: Double, radiusKm: Double, filters: SpotFilters, searchText: String) async throws -> [SpotDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("spots"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "radius_km", value: String(radiusKm))
        ]

        if !searchText.isEmpty {
            items.append(URLQueryItem(name: "q", value: searchText))
        }
        if let price = filters.selectedPrice {
            items.append(URLQueryItem(name: "cost_range", value: price.rawValue))
        }
        if let age = filters.selectedAge {
            items.append(URLQueryItem(name: "age", value: String(age)))
        }
        if !filters.selectedTags.isEmpty {
            items.append(URLQueryItem(name: "tags", value: filters.selectedTags.joined(separator: ",")))
        }

        components?.queryItems = items
        guard let url = components?.url else { throw URLError(.badURL) }
        return try await get(url: url, responseType: [SpotDTO].self)
    }

    func fetchFavorites(userId: String) async throws -> [SpotDTO] {
        var request = URLRequest(url: baseURL.appendingPathComponent("favorites"))
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        let response = try await get(request: request, responseType: FavoritesResponseDTO.self)
        return response.items
    }

    func addFavorite(userId: String, spotId: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("favorites"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        request.httpBody = try JSONEncoder().encode(["spot_id": spotId])
        _ = try await get(request: request, responseType: [String: Bool].self)
    }

    func removeFavorite(userId: String, spotId: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("favorites/\(spotId)"))
        request.httpMethod = "DELETE"
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        _ = try await get(request: request, responseType: [String: Bool].self)
    }

    private func get<T: Decodable>(url: URL, responseType: T.Type) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func get<T: Decodable>(request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
