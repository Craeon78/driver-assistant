
import SwiftUI

import MapKit

import CoreLocation

  

//======================================

// MARK: - MapView (Split Layout)

//======================================

//

// Purpose:

// - Left panel: map tools, pin management, future run planning

// - Right panel: live map with GPS blue dot + session pins

//

// Phase 1 scope (pre-persistence):

// - Session pins only (lost on restart)

// - Tap-to-drop pin workflow

// - Manual category selection

// - NHVR base radius overlay (if address provided in settings)

//

// Post-persistence scope:

// - Durable pins with stable IDs

// - Pin editing (rename, category, delete)

// - Saved runs (ordered stop sequences)

// - Breadcrumb trails (GPS history)

//

// Design separation:

// - MapScreen = container (left panel + right pane)

// - MapPane = actual Map + overlays + tap handling

//

//======================================

  

//======================================

// MARK: - Map Pane (Live Map + Overlays)

//======================================

//

// Purpose (pre-persistence):

// - Show live GPS position (UserAnnotation blue dot)

// - Render session pins with category colors

// - Show NHVR base radius (if configured)

// - Handle tap-to-drop pin workflow

//

// Important state:

// - `pins` is session-only (pre-persistence)

// - `cameraPosition` is user-controlled (auto-follow optional)

// - `didUserMoveMap` prevents fighting with auto-recenter

// - `programmaticMove` flag prevents false "user panned" detection

//

// Post-persistence:

// - Pins become durable (stable IDs, editable)

// - Camera position may be restored from last session

// - Breadcrumb trails may be rendered from JSONL files

//

//======================================

  

struct MapPane: View {

  

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @Binding var isFollowingUser: Bool

    @Binding var didUserMoveMap: Bool

    @Binding var cameraPosition: MapCameraPosition

    @Binding var pins: [LocationPin]

    @State private var selectedCategory: LocationCategory = .customer

    @State private var baseCoordinate: CLLocationCoordinate2D? = nil

    // prevents “camera moved” callback from disabling follow when WE moved it

    @State private var programmaticMove: Bool = false

    var body: some View {

        ZStack {

            MapReader { proxy in

                Map(position: $cameraPosition) {

                    UserAnnotation()

                    if let base = baseCoordinate {

                        MapCircle(center: base, radius: model.settings.nhvrRadiusKm * 1000)

                            .foregroundStyle(.blue.opacity(0.12))

                        Marker("NHVR Base", coordinate: base).tint(.blue)

                    }

                    ForEach(Array(pins.enumerated()), id: \.element.id) { idx, pin in

                        let number = idx + 1

                        Annotation(pin.name, coordinate: pin.coordinate) {

                            ZStack {

                                Circle()

                                    .fill(Color.blue.opacity(0.9))

                                    .frame(width: 30, height: 30)

                                Text("\(number)")

                                    .font(.caption.bold())

                                    .foregroundStyle(.white)

                            }

                            .overlay(

                                Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)

                            )

                            .shadow(radius: 2)

                            .accessibilityLabel("\(pin.category.rawValue) \(number): \(pin.name)")

                        }

                    }

                }

                .onMapCameraChange { _ in

                    if programmaticMove {

                        programmaticMove = false

                        return

                    }

                    // user touched the map -> they’re steering now, so stop following

                    didUserMoveMap = true

                    if isFollowingUser {

                        isFollowingUser = false

                    }

                }

                .onTapGesture { location in

                    if let coord = proxy.convert(location, from: .local) {

                        let newPin = LocationPin(

                            coordinate: coord,

                            category: selectedCategory

                        )

                        pins.append(newPin)

                    }

                }

            }

            // keep your overlay picker for now (you can move it left later)

            VStack {

                HStack {

                    Picker("Category", selection: $selectedCategory) {

                        ForEach(LocationCategory.allCases) { category in

                            Text(category.rawValue).tag(category)

                        }

                    }

                    .pickerStyle(.menu)

                    if !pins.isEmpty {

                        Button("Undo last") { _ = pins.popLast() }

                    }

                }

                .padding(8)

                .background(.thinMaterial)

                .cornerRadius(10)

                .padding()

                Spacer()

            }

        }

        .onAppear {

            geocodeNhvrBaseIfNeeded()

        }

        .onChange(of: model.settings.nhvrBaseAddress) { _, _ in

            geocodeNhvrBaseIfNeeded()

        }

        .onChange(of: locationManager.lastLocation) { _, newValue in

            guard isFollowingUser, let coord = newValue?.coordinate else { return }

            programmaticMove = true

            cameraPosition = .region(

                MKCoordinateRegion(

                    center: coord,

                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)

                )

            )

        }

        .onReceive(locationManager.$lastDeltaMeters) { delta in

            DebugLog.gps("🟢 lastDeltaMeters → \(delta)")

            guard delta > 0 else { return }

            model.ingestGpsDeltaMeters(delta)

        }

    }

    private func geocodeNhvrBaseIfNeeded() {

        let address = model.settings.nhvrBaseAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty else {

            baseCoordinate = nil

            return

        }

        CLGeocoder().geocodeAddressString(address) { placemarks, error in

            guard error == nil else { return }

            guard let coord = placemarks?.first?.location?.coordinate else { return }

            DispatchQueue.main.async {

                baseCoordinate = coord

                if !didUserMoveMap && !isFollowingUser {

                    self.programmaticMove = true

                    cameraPosition = .region(

                        MKCoordinateRegion(

                            center: coord,

                            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)

                        )

                    )

                }

            }

        }

    }

}

  

//======================================

// MARK: - Map screen (split layout)

//======================================

//

// Purpose:

// - Left column: placeholder “Map tools” panel.

// - Right column: the actual map pane.

// - Mirrors the same split-view approach as LoadPlanView.

//

struct MapScreen: View {

    @EnvironmentObject var model: AppModel

    // Phase 1 session-only map state (shared between left panel + MapPane)

    @State private var pins: [LocationPin] = []

    @State private var didUserMoveMap: Bool = false

    @State private var cameraPosition: MapCameraPosition = .region(

        MKCoordinateRegion(

            center: CLLocationCoordinate2D(latitude: -27.25, longitude: 152.95),

            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)

        )

    )

    @EnvironmentObject var locationManager: LocationManager

    @State private var isFollowingUser: Bool = false

    var body: some View {

            HStack(spacing: 0) {

                // LEFT: tools panel (placeholder scaffolding)

                VStack(alignment: .leading, spacing: 12) {

                    Button {

                        isFollowingUser.toggle()

                        if isFollowingUser {

                            locationManager.requestPermissionIfNeeded()

                            locationManager.start()

                            didUserMoveMap = false

                        } else {

                        }

                    } label: {

                        Label(isFollowingUser ? "Following" : "Follow Me",

                              systemImage: isFollowingUser ? "location.fill" : "location")

                    }

                    .buttonStyle(.bordered)

                    Text("Map tools")

                        .font(.headline)

                    // ---------------------------------

                    // Pins (session only)

                    // ---------------------------------

                    Text("Pins (session)")

                        .font(.subheadline)

                    if pins.isEmpty {

                        Text("No pins yet. Tap on the map to drop one.")

                            .font(.caption)

                            .foregroundColor(.secondary)

                            .fixedSize(horizontal: false, vertical: true)

                    } else {

                        List {

                            ForEach(Array(pins.enumerated()), id: \.element.id) { idx, pin in

                                let number = idx + 1

                                Button {

                                    // Jump the map to this pin

                                    didUserMoveMap = true

                                    cameraPosition = .region(

                                        MKCoordinateRegion(

                                            center: pin.coordinate,

                                            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)

                                        )

                                    )

                                } label: {

                                    HStack(spacing: 10) {

                                        // Number badge

                                        Text("\(number)")

                                            .font(.caption.bold())

                                            .foregroundStyle(.white)

                                            .frame(width: 26, height: 26)

                                            .background(Circle().fill(Color.blue.opacity(0.9)))

                                        VStack(alignment: .leading, spacing: 2) {

                                            Text(pin.name)

                                                .font(.body)

                                            Text(pin.category.rawValue)

                                                .font(.caption2)

                                                .foregroundColor(.secondary)

                                        }

                                        Spacer()

                                    }

                                }

                            }

                            .onDelete { indexSet in

                                pins.remove(atOffsets: indexSet)

                            }

                        }

                        .listStyle(.plain)

                    }

                    // Keep your future scaffolding notes if you want them:

                    Divider()

                    Text("Later:\n• Saved milk runs\n• Edit / reorder stops\n• Filters (night, DG type, etc.)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                }

                .padding()

                .frame(maxWidth: 340, alignment: .topLeading)

                .background(Color(.systemBackground))

                .clipped()

                Divider()

                // RIGHT: actual map

                MapPane(

                    isFollowingUser: $isFollowingUser,

                    didUserMoveMap: $didUserMoveMap,

                    cameraPosition: $cameraPosition,

                    pins: $pins

                )

            }

            .navigationTitle("Map")

    }

}
