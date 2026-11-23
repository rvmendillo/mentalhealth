import SwiftUI
import UIKit
import RenewedMindKit

@main
struct RenewedMindApp: App {
    @StateObject private var model: AppModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-uiTesting")
        let store: DataStore
        if isUITesting {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("RenewedMindUITests", isDirectory: true)
                .appendingPathComponent("data.json")
            store = DataStore(fileURL: url)
            if arguments.contains("-resetData") { try? store.deleteAll() }
            UIView.setAnimationsEnabled(false)
        } else {
            let url = (try? DataStore.defaultURL())
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("RenewedMind-data.json")
            store = DataStore(fileURL: url)
        }
        let model = AppModel(store: store, isUITesting: isUITesting)
        if isUITesting {
            if arguments.contains("-skipOnboarding") && !model.data.profile.hasCompletedOnboarding {
                model.completeOnboarding(name: "Grace")
            }
            model.setAIMode(arguments.contains("-onDeviceAI") ? .onDevice : .offline)
        }
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Palette.teal)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.data.profile.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .alert("Renewed Mind", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
        .task { await model.refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshReminders() } }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)
            RenewView()
                .tabItem { Label("Renew", systemImage: "arrow.triangle.2.circlepath") }
                .tag(AppTab.renew)
            PracticesView()
                .tabItem { Label("Practices", systemImage: "leaf") }
                .tag(AppTab.practices)
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppTab.library)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.insights)
        }
    }
}
