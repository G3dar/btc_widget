import Foundation
import Combine

@MainActor
class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published var deviceToken: String?
    @Published var isRegistered = false
    @Published var registrationError: String?

    private let tokenKey = "apns_device_token"

    private init() {
        // Load saved token
        deviceToken = UserDefaults.standard.string(forKey: tokenKey)
    }

    // Save token locally
    func saveToken(_ token: String) {
        deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    // Register token with backend
    func registerTokenWithBackend() async {
        guard let token = deviceToken else {
            print("No device token to register")
            return
        }

        do {
            try await BackendService.shared.registerPushToken(token)
            isRegistered = true
            registrationError = nil
            print("Push token registered with backend")
        } catch {
            isRegistered = false
            registrationError = error.localizedDescription
            print("Failed to register push token: \(error)")
        }
    }
}
