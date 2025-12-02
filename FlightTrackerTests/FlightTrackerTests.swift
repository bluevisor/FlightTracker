//
//  FlightTrackerTests.swift
//  FlightTrackerTests
//
//  Created by John Zheng on 12/2/25.
//

import Testing
import MapKit
import SwiftUI
@testable import FlightTracker

struct FlightTrackerTests {

    @Test func testZoomIn() async throws {
        let viewModel = await FlightViewModel()
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )

        await MainActor.run {
            viewModel.updateViewRegion(initialRegion)
            // Zoom in (multiplier 0.8)
            viewModel.adjustZoom(multiplier: 0.8)
        }

        let newRegion = await viewModel.currentViewRegion
        // Span should decrease to 8.
        #expect(newRegion?.span.latitudeDelta == 8.0)
        #expect(newRegion?.span.longitudeDelta == 8.0)
    }

    @Test func testZoomOut() async throws {
        let viewModel = await FlightViewModel()
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )

        await MainActor.run {
            viewModel.updateViewRegion(initialRegion)
            // Zoom out (multiplier 1.25)
            viewModel.adjustZoom(multiplier: 1.25)
        }

        let newRegion = await viewModel.currentViewRegion
        // Span should increase to 12.5.
        #expect(newRegion?.span.latitudeDelta == 12.5)
        #expect(newRegion?.span.longitudeDelta == 12.5)
    }

    @Test func testContinuousZoomIn() async throws {
        let viewModel = await FlightViewModel()
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )

        await MainActor.run {
            viewModel.updateViewRegion(initialRegion)
            // Continuous zoom uses smaller multiplier (0.95)
            viewModel.adjustZoom(multiplier: 0.95)
        }

        let newRegion = await viewModel.currentViewRegion
        // Span should decrease to 9.5
        #expect(newRegion?.span.latitudeDelta == 9.5)
        #expect(newRegion?.span.longitudeDelta == 9.5)
    }

    @Test func testZoomLimits() async throws {
        let viewModel = await FlightViewModel()
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        await MainActor.run {
            viewModel.updateViewRegion(initialRegion)
            // Try to zoom in beyond minimum (0.01)
            viewModel.adjustZoom(multiplier: 0.1)
        }

        let newRegion = await viewModel.currentViewRegion
        // Span should be clamped to minimum 0.01
        #expect(newRegion?.span.latitudeDelta == 0.01)
        #expect(newRegion?.span.longitudeDelta == 0.01)
    }

    @Test func testSelectFlight() async throws {
        let viewModel = await FlightViewModel()

        // Create a test flight with correct initializer
        let testFlight = Flight(
            id: "test123",
            callsign: "TEST123",
            originCountry: "Test Country",
            registration: "N12345",
            aircraftType: "B737",
            coordinate: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.4),
            altitudeBaro: 3048.0, // 10000 ft in meters
            altitudeGeo: nil,
            groundSpeed: 231.5, // 450 knots in m/s
            airSpeed: nil,
            track: 180,
            verticalRate: 0
        )

        await MainActor.run {
            if let flight = testFlight {
                viewModel.flights = [flight]
                viewModel.selectFlight(flight)
            }
        }

        let selectedFlight = await viewModel.selectedFlight
        #expect(selectedFlight?.id == "test123")
        #expect(selectedFlight?.callsign == "TEST123")
    }
}
