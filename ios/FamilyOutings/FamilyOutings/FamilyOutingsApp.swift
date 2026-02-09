import SwiftUI
import MapKit
import CoreLocation
import AuthenticationServices
import Combine

// MARK: - Data Model
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

enum DataFetchStatus: Equatable {
    case idle
    case fetching
    case success
    case error(String)
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

    func fetchSpots(in region: MKCoordinateRegion) {
        // TODO: Replace with API call
        spots = [
            Spot(
                id: "1",
                name: "テストスポット1",
                latitude: region.center.latitude,
                longitude: region.center.longitude,
                address: "東京都千代田区",
                description: "テストのスポットです",
                url: "https://example.com",
                priceRange: .free,
                ageMin: 0,
                ageMax: 12,
                tags: ["屋内", "雨でもOK"],
                source: "管理者"
            ),
            Spot(
                id: "2",
                name: "テストスポット2",
                latitude: region.center.latitude,
                longitude: region.center.longitude + 0.001,
                address: "東京都千代田区",
                description: "別のテストスポットです",
                url: "https://example.com",
                priceRange: .u1000,
                ageMin: 3,
                ageMax: 10,
                tags: ["屋外", "ベビーカーOK"],
                source: "管理者"
            )
        ]
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

    func signInAsGuest() {
        isLoggedIn = true
    }

    func signOut() {
        isLoggedIn = false
    }
}

// MARK: - Favorites
final class DataManager: ObservableObject {
    @Published private(set) var favorites: Set<String> = []

    private let key = "favorites"

    init() {
        load()
    }

    func toggleFavorite(_ spotId: String) {
        if favorites.contains(spotId) {
            favorites.remove(spotId)
        } else {
            favorites.insert(spotId)
        }
        save()
    }

    func isFavorite(_ spotId: String) -> Bool {
        favorites.contains(spotId)
    }

    private func save() {
        let array = Array(favorites)
        UserDefaults.standard.set(array, forKey: key)
    }

    private func load() {
        if let array = UserDefaults.standard.array(forKey: key) as? [String] {
            favorites = Set(array)
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

    var body: some View {
        Map(coordinateRegion: $locationManager.region, annotationItems: spotDataService.spots) { spot in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .onTapGesture { selectedSpot = spot }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        dataManager.toggleFavorite(spot.id)
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
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = spot.name
        item.openInMaps()
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
                        NavigationLink(destination: SpotDetailView(spot: spot, dataManager: dataManager)) {
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
                    spotDataService.fetchSpots(in: locationManager.region)
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
