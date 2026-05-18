/*
 SalesforceSDKManager+SwiftUI.swift
 SalesforceSDKCore

 Created by Takashi Arai on 05/11/26.

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

/// SwiftUI-friendly extensions for SalesforceSDKManager.
/// These methods provide async/await wrappers for SDK initialization and lifecycle operations,
/// enabling idiomatic usage within SwiftUI's `.task {}` modifier and other async contexts.
extension SalesforceManager {

    /// Asynchronously initializes the Salesforce SDK.
    ///
    /// This method is a SwiftUI-friendly wrapper around ``SalesforceManager/initializeSDK()``
    /// that can be called from async contexts such as SwiftUI's `.task {}` modifier.
    ///
    /// The initialization is performed on the main actor to ensure all SDK setup
    /// (including UI-related configuration) occurs on the main thread.
    ///
    /// Example usage in a SwiftUI app:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///         }
    ///         .task {
    ///             await SalesforceManager.initialize()
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This method must be called before any other SDK operations.
    /// - Note: This method is safe to call multiple times; subsequent calls are no-ops.
    @MainActor
    public static func initialize() async {
        SalesforceManager.initializeSDK()
    }

    /// Asynchronously initializes the Salesforce SDK with a custom manager class.
    ///
    /// This method is a SwiftUI-friendly wrapper around ``SalesforceManager/initializeSDK(manager:)``
    /// for apps that require a custom SDK manager subclass.
    ///
    /// Example usage:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///         }
    ///         .task {
    ///             await SalesforceManager.initialize(manager: MyCustomSDKManager.self)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter manager: A subclass of ``SalesforceManager`` to use for SDK operations.
    /// - Note: This method must be called before any other SDK operations.
    /// - Note: This method is safe to call multiple times; subsequent calls are no-ops.
    @MainActor
    public static func initialize(manager: AnyClass) async {
        SalesforceManager.initializeSDK(manager: manager)
    }
}
