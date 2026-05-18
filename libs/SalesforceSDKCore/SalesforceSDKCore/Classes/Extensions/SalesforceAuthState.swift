/*
 SalesforceAuthState.swift
 SalesforceSDKCore

 Created by Takashi Arai on 05/12/26.

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import Observation

/// SwiftUI-friendly observable wrapper around the SDK's authentication state.
///
/// `SalesforceAuthState` exposes the current user account and login status as `@Observable`
/// properties so SwiftUI views can react to login/logout transitions without subscribing to
/// `NSNotification` directly. It also provides async `login()`/`logout()` convenience methods
/// that wrap ``UserAccountManager``'s existing completion-based APIs.
///
/// ## Why this exists
///
/// The SDK already broadcasts auth-state changes via three notifications declared on
/// ``UserAccountManager``:
/// - ``UserAccountManager/didLogInUser`` (`kSFNotificationUserDidLogIn`)
/// - ``UserAccountManager/didLogoutUser`` (`kSFNotificationUserDidLogout`)
/// - ``UserAccountManager/didSwitchUser`` (`kSFNotificationUserDidSwitch`)
///
/// Hosts can — and historically did — call `NotificationCenter.default.addObserver` directly,
/// then translate to `@Published` properties on an `ObservableObject`. That pattern still
/// works and is unchanged. This class is an *additive* convenience so SwiftUI hosts don't have
/// to write that bridging code themselves, and so newer apps can adopt the modern Swift
/// `@Observable` macro without inheriting from `ObservableObject`.
///
/// ## Usage
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var auth = SalesforceAuthState()
///
///     var body: some Scene {
///         WindowGroup {
///             Group {
///                 if auth.isLoggedIn {
///                     ContentView()
///                 } else {
///                     LoginView(auth: auth)
///                 }
///             }
///             .environment(auth)
///         }
///         .task { await SalesforceManager.initialize() }
///     }
/// }
/// ```
///
/// ## Threading
/// Properties are updated on the main thread because notifications are observed on
/// `OperationQueue.main`. Reads from any thread are safe — the `@Observable` macro provides
/// the necessary synchronization for SwiftUI to track property accesses.
///
/// ## Lifetime
/// Hold a single instance per app at the scene/app level (e.g., as `@State` on the `App`
/// struct). Creating multiple instances is harmless — each subscribes independently to the
/// same broadcast notifications — but a single instance is cheaper and avoids redundant work.
@available(iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class SalesforceAuthState {

    /// The currently logged-in user, or `nil` if no user is logged in.
    ///
    /// Updated automatically when the SDK posts a login, logout, or user-switch notification.
    public private(set) var currentUser: UserAccount?

    /// Convenience flag derived from ``currentUser``.
    ///
    /// Equivalent to `currentUser != nil`. Hosts typically branch their root view on this:
    /// ```swift
    /// if auth.isLoggedIn { ContentView() } else { LoginView() }
    /// ```
    public var isLoggedIn: Bool { currentUser != nil }

    /// Notification observers retained for the lifetime of this instance.
    ///
    /// Stored as `@ObservationIgnored` so reads/writes don't trigger SwiftUI updates.
    @ObservationIgnored
    private var observers: [NSObjectProtocol] = []

    /// Creates a new auth-state observer.
    ///
    /// The initializer seeds `currentUser` from `UserAccountManager.shared.currentUserAccount`
    /// (so apps that launch with an already-authenticated user start in the logged-in state)
    /// and subscribes to the SDK's login/logout/switch notifications.
    public init() {
        self.currentUser = UserAccountManager.shared.currentUserAccount
        registerForAuthNotifications()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Async convenience

    /// Asynchronously kicks off the OAuth login flow.
    ///
    /// Wraps ``UserAccountManager``'s completion-based `login(_:)` so SwiftUI hosts can use
    /// async/await directly:
    /// ```swift
    /// Button("Sign in") {
    ///     Task { try await auth.login() }
    /// }
    /// ```
    ///
    /// On success, the returned `UserAccount` is also reflected in ``currentUser`` (the
    /// notification observer set up in `init` updates it).
    ///
    /// - Returns: The authenticated `UserAccount`.
    /// - Throws: `UserAccountManagerError.loginFailed` if the OAuth flow fails.
    @discardableResult
    public func login() async throws -> UserAccount {
        try await UserAccountManager.shared.login()
    }

    /// Asynchronously logs out the current user.
    ///
    /// Wraps ``UserAccountManager``'s synchronous `logout()` in an async signature so callers
    /// can `await` it consistently with `login()`. After the call returns, ``isLoggedIn`` will
    /// be `false`.
    public func logout() async {
        await UserAccountManager.shared.logout()
    }

    // MARK: - Notification wiring

    private func registerForAuthNotifications() {
        let center = NotificationCenter.default
        let queue = OperationQueue.main

        let onLogin = center.addObserver(
            forName: UserAccountManager.didLogInUser,
            object: nil,
            queue: queue
        ) { [weak self] _ in
            // Use MainActor.assumeIsolated because OperationQueue.main is the main thread,
            // but the closure isn't statically annotated as @MainActor.
            MainActor.assumeIsolated {
                self?.currentUser = UserAccountManager.shared.currentUserAccount
            }
        }

        let onLogout = center.addObserver(
            forName: UserAccountManager.didLogoutUser,
            object: nil,
            queue: queue
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentUser = nil
            }
        }

        let onSwitch = center.addObserver(
            forName: UserAccountManager.didSwitchUser,
            object: nil,
            queue: queue
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentUser = UserAccountManager.shared.currentUserAccount
            }
        }

        observers = [onLogin, onLogout, onSwitch]
    }
}
