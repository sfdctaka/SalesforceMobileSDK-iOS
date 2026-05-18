/*
 UserAccountManager+Async.swift
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

/// Async/await convenience wrappers around ``UserAccountManager``'s OAuth login and logout
/// methods.
///
/// ## Why this exists
///
/// The existing Swift API on ``UserAccountManager`` exposes login through a Result-typed
/// completion block:
/// ```swift
/// _ = UserAccountManager.shared.login { result in
///     switch result {
///     case .success(let (userAccount, _)): // ...
///     case .failure(let error):             // ...
///     }
/// }
/// ```
///
/// This is fine, but per the SDK's stated direction (CLAUDE.md):
/// > Async/await preferred over completion handlers. Completion-based methods are being
/// > deprecated in favor of async/await (ongoing since 13.0).
///
/// So this extension is on-strategy, not a hackathon shortcut. The wrappers here:
/// - keep the existing completion-based `login(_:)` and synchronous `logout()` untouched
///   (no breaking change to any existing caller),
/// - add `async`-shaped versions that bridge to the existing implementations via
///   `withCheckedThrowingContinuation`,
/// - return the same `UserAccount` / `UserAccountManagerError` types the completion-based
///   API uses (no new error type added).
///
/// ## Usage
/// ```swift
/// Button("Sign in") {
///     Task {
///         do {
///             let user = try await UserAccountManager.shared.login()
///             // use user...
///         } catch {
///             // handle UserAccountManagerError.loginFailed
///         }
///     }
/// }
/// ```
extension UserAccountManager {

    /// Asynchronously kicks off the OAuth login flow with the previously-configured credentials.
    ///
    /// Bridges the existing completion-based ``login(_:)`` to async/await. The flow is otherwise
    /// identical: the SDK presents the configured login UI (web view, native login, or advanced
    /// auth — depending on flags), the user completes the flow, and on success the SDK posts
    /// `kSFNotificationUserDidLogIn` and sets ``UserAccountManager/currentUserAccount``.
    ///
    /// - Returns: The authenticated `UserAccount`.
    /// - Throws: `UserAccountManagerError.loginFailed` if the OAuth flow fails for any reason.
    /// - Important: This method does not retry on failure. If you need retry behavior, layer
    ///   it in the caller.
    @discardableResult
    public func login() async throws -> UserAccount {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserAccount, Error>) in
            // The completion-based login() returns Bool (whether the call kicked off auth);
            // the actual outcome arrives in the completion. We discard the return because
            // queueing semantics are an implementation detail callers don't need at this layer.
            _ = self.login { result in
                switch result {
                case .success(let (userAccount, _)):
                    continuation.resume(returning: userAccount)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Asynchronously logs out the current user.
    ///
    /// The underlying ``UserAccountManager/logout()`` is synchronous from the caller's
    /// perspective (it returns immediately and the actual sign-out work happens via
    /// `kSFNotificationUserWillLogout` / `kSFNotificationUserDidLogout` posts). This wrapper
    /// awaits the post-logout notification so the awaiting `Task` resumes only when logout
    /// has fully completed — making it composable with subsequent UI state changes.
    ///
    /// If logout has already happened (no current user), this returns immediately.
    public func logout() async {
        guard self.currentUserAccount != nil else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Subscribe to the did-logout notification before kicking off logout to avoid a
            // race where the notification fires before the observer is added.
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UserAccountManager.didLogoutUser,
                object: nil,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume()
            }
            self.logout()
        }
    }
}
