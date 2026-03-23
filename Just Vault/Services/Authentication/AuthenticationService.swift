//
//  AuthenticationService.swift
//  Just Vault
//
//  Handles Apple Sign In and Cognito authentication
//

import Foundation
import UIKit
import AuthenticationServices
import Combine
import AWSCognitoIdentityProvider
import AWSCognitoIdentity
import ClientRuntime

@MainActor
class AuthenticationService: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var continuation: CheckedContinuation<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    // AWS Configuration
    private let userPoolId = AWSConfig.userPoolId
    private let clientId = AWSConfig.clientId
    private let identityPoolId = AWSConfig.identityPoolId
    private let region = AWSConfig.region
    
    override init() {
        super.init()
        NotificationCenter.default.publisher(for: .userProfileDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    if let user = await self.loadCurrentUser() {
                        self.currentUser = user
                    }
                }
            }
            .store(in: &cancellables)
        Task { @MainActor in
            await StoreKitService.shared.updatePurchasedProducts()
            await StoreKitService.shared.applyTierToCurrentUser()
            if let user = await self.loadCurrentUser() {
                self.currentUser = user
                self.isAuthenticated = true
            }
        }
    }
    
    /// Initiate Apple Sign In flow
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            do {
                try await completeSignIn(with: authorization)
                
                continuation?.resume()
                continuation = nil
                
            } catch {
                errorMessage = error.localizedDescription
                continuation?.resume(throwing: error)
                continuation = nil
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = error.localizedDescription
        continuation?.resume(throwing: AuthenticationError.appleSignInFailed)
        continuation = nil
    }
    
    /// Handles the successful Apple authorization payload and completes the Cognito/AWS sign-in flow.
    /// This can be called directly from custom Sign In with Apple buttons outside the delegate-driven path.
    /// - Parameter enterApp: If `false`, the user profile and credentials are created locally but `isAuthenticated` stays `false` so the UI stays on sign-up until you finish IAP (paid plans). Then set `isAuthenticated = true` yourself.
    func completeSignIn(with authorization: ASAuthorization, enterApp: Bool = true) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthenticationError.appleSignInFailed
        }
        
        let appleUserID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        let cognitoIdentityId = try await getAWSCredentials(appleIdentityToken: identityTokenString)
        
        let user = try await createOrLoadUser(
            appleUserID: appleUserID,
            email: email,
            fullName: fullName,
            cognitoIdentityId: cognitoIdentityId
        )
        
        currentUser = user
        isAuthenticated = enterApp
    }

    /// Clears session after Apple + backend work succeeded but the user did not complete paid signup (e.g. cancelled the App Store purchase). Keeps first-time sign-up UI (`isReturningUser` untouched).
    func revertPendingPaidSignUpSession() async {
        let userId = UserDefaults.standard.string(forKey: "currentUserId")
        currentUser = nil
        isAuthenticated = false
        CredentialManager.shared.clearCredentials()
        DynamoDBService.shared.clearClient()
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        if let userId = userId {
            UserDefaults.standard.removeObject(forKey: "currentUser_\(userId)")
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
    
    // MARK: - Cognito Integration
    
    private func exchangeAppleTokenForCognito(identityToken: String) async throws -> CognitoTokens {
        // Exchange Apple ID token for Cognito tokens
        // This uses Cognito's OIDC provider flow with Apple Sign-In
        
        // Create Cognito Identity Provider client
        let config = try await CognitoIdentityProviderClient.CognitoIdentityProviderClientConfig(
            region: region
        )
        let client = CognitoIdentityProviderClient(config: config)
        
        // For Apple Sign-In as OIDC provider, we use InitiateAuth with CUSTOM_AUTH flow
        // The Apple identity token is passed in auth parameters
        let authParameters: [String: String] = [
            "IDENTITY_TOKEN": identityToken,
            "PROVIDER": "SignInWithApple" // This depends on how Apple is configured in Cognito
        ]
        
        let input = InitiateAuthInput(
            authFlow: .customAuth,
            authParameters: authParameters,
            clientId: clientId
        )
        
        do {
            let response = try await client.initiateAuth(input: input)
            
            guard let authResult = response.authenticationResult,
                  let idToken = authResult.idToken,
                  let accessToken = authResult.accessToken,
                  let refreshToken = authResult.refreshToken else {
                throw AuthenticationError.cognitoTokenExchangeFailed
            }
            
            return CognitoTokens(
                idToken: idToken,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        } catch {
            // If CUSTOM_AUTH doesn't work, try alternative approach
            // Some Cognito configurations use different flows for OIDC providers
            throw AuthenticationError.cognitoTokenExchangeFailed
        }
    }
    
    private func getAWSCredentials(appleIdentityToken: String) async throws -> String {
        // Use the Apple identity token directly with the Cognito Identity Pool.
        // This avoids the fragile user-pool token exchange path and matches a
        // standard "Sign in with Apple -> federated identity -> AWS credentials" flow.
        
        // Create Cognito Identity client
        let config = try await CognitoIdentityClient.CognitoIdentityClientConfig(
            region: region
        )
        let client = CognitoIdentityClient(config: config)
        
        // Identity Pools use Apple's issuer string as the provider key.
        let logins: [String: String] = ["appleid.apple.com": appleIdentityToken]
        
        // Step 1: Get Identity ID
        let getIdInput = GetIdInput(
            identityPoolId: identityPoolId,
            logins: logins
        )
        
        let getIdResponse: GetIdOutput
        do {
            getIdResponse = try await client.getId(input: getIdInput)
        } catch {
            print("Auth getId failed: \(error.localizedDescription)")
            throw AuthenticationError.awsCredentialsFailed
        }
        guard let identityId = getIdResponse.identityId else {
            throw AuthenticationError.awsCredentialsFailed
        }
        
        // Step 2: Get credentials for the identity
        let getCredentialsInput = GetCredentialsForIdentityInput(
            identityId: identityId,
            logins: logins
        )
        
        let credentialsResponse: GetCredentialsForIdentityOutput
        do {
            credentialsResponse = try await client.getCredentialsForIdentity(input: getCredentialsInput)
        } catch {
            print("Auth getCredentialsForIdentity failed: \(error.localizedDescription)")
            throw AuthenticationError.awsCredentialsFailed
        }
        guard let awsCredentials = credentialsResponse.credentials else {
            throw AuthenticationError.awsCredentialsFailed
        }
        
        // Store credentials in CredentialManager
        do {
            try CredentialManager.shared.storeCredentials(
                identityId: identityId,
                accessKeyId: awsCredentials.accessKeyId,
                secretAccessKey: awsCredentials.secretKey, // Note: AWS SDK uses 'secretKey' not 'secretAccessKey'
                sessionToken: awsCredentials.sessionToken,
                expiration: awsCredentials.expiration,
                tokens: nil
            )
        } catch {
            // Log error but don't fail authentication
            print("Failed to store credentials: \(error.localizedDescription)")
        }
        
        // Return the identity ID (we'll use this as the user ID)
        return identityId
    }
    
    private func createOrLoadUser(
        appleUserID: String,
        email: String?,
        fullName: PersonNameComponents?,
        cognitoIdentityId: String
    ) async throws -> User {
        // Check if user exists locally
        if let existingUser = try? await loadUserFromLocalStorage(identityId: cognitoIdentityId) {
            return existingUser
        }

        // After reinstall, local storage may be gone even though the user still
        // exists in DynamoDB. Restore the profile from cloud before creating a new one.
        if let cloudUser = try? await DynamoDBService.shared.loadUserProfile(userId: cognitoIdentityId) {
            try await saveUserToLocalStorage(cloudUser)
            return cloudUser
        }
        
        // Create new user
        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let user = User(
            id: cognitoIdentityId,
            appleUserId: appleUserID,
            email: email,
            name: name.isEmpty ? nil : name,
            createdAt: Date(),
            lastActiveAt: Date(),
            subscriptionTier: .free,
            subscriptionStatus: .none,
            cloudStorageUsedBytes: 0,
            cloudStorageQuotaBytes: Int64(AppConfig.freeTierCloudStorageMB * 1_000_000)
        )
        
        // Save to local storage
        try await saveUserToLocalStorage(user)
        
        return user
    }
    
    // MARK: - Local Storage Helpers
    
    private func loadUserFromLocalStorage(identityId: String) async throws -> User {
        // Load user ID from UserDefaults
        guard let savedUserId = UserDefaults.standard.string(forKey: "currentUserId"),
              savedUserId == identityId else {
            throw AuthenticationError.userNotFound
        }
        
        // Load user JSON from UserDefaults
        let userKey = "currentUser_\(identityId)"
        guard let userData = UserDefaults.standard.data(forKey: userKey) else {
            throw AuthenticationError.userNotFound
        }
        
        // Decode user from JSON
        let decoder = JSONDecoder()
        do {
            let user = try decoder.decode(User.self, from: userData)
            return user
        } catch {
            throw AuthenticationError.userNotFound
        }
    }
    
    func saveUserToLocalStorage(_ user: User) async throws {
        // Encode user to JSON
        let encoder = JSONEncoder()
        guard let userData = try? encoder.encode(user) else {
            throw AuthenticationError.notImplemented
        }
        
        // Save user ID for quick lookup
        UserDefaults.standard.set(user.id, forKey: "currentUserId")
        
        // Save user JSON with identity ID as key
        let userKey = "currentUser_\(user.id)"
        UserDefaults.standard.set(userData, forKey: userKey)
        currentUser = user
        
        // Synchronize to ensure data is saved
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
    }
    
    // MARK: - Load Current User
    
    func loadCurrentUser() async -> User? {
        // Get current user ID from UserDefaults
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId") else {
            return nil
        }
        
        // Try to load user from local storage
        do {
            let user = try await loadUserFromLocalStorage(identityId: userId)
            return user
        } catch {
            return nil
        }
    }
    
    // MARK: - Sign Out

    func signOut() async {
        let userId = UserDefaults.standard.string(forKey: "currentUserId")
        currentUser = nil
        isAuthenticated = false
        CredentialManager.shared.clearCredentials()
        DynamoDBService.shared.clearClient()
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        if let userId = userId {
            UserDefaults.standard.removeObject(forKey: "currentUser_\(userId)")
        }
        UserDefaults.standard.set(true, forKey: "com.justvault.isReturningUser")
    }

    // MARK: - Delete Account

    /// Permanently deletes all user data (cloud + local) then signs out. Fails entirely if cloud step fails (no partial delete).
    func deleteAccount(userId: String) async throws {
        do {
            try await DynamoDBService.shared.deleteAllUserCloudData(userId: userId)
        } catch {
            throw AccountDeletionError.cloudDeletionFailed(underlying: error)
        }
        let localFiles = (try? LocalFileMetadataService.shared.loadAllFiles(userId: userId)) ?? []
        let storage = LocalStorageService()
        for file in localFiles {
            try? storage.deleteEncryptedFile(fileId: file.id)
            try? storage.deleteEncryptedFile(fileId: "\(file.id)_thumb")
            LocalFileMetadataService.shared.deleteFileMetadata(fileId: file.id, userId: userId, spaceId: file.spaceId)
        }
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("space_files_\(userId)_") || key.hasPrefix("file_metadata_\(userId)_") || key == "spaces_\(userId)" {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        try? SecureEnclaveManager.deleteMasterKey()
        await signOut()
    }
}

// MARK: - Supporting Types

struct CognitoTokens {
    let idToken: String
    let accessToken: String
    let refreshToken: String
}

enum AuthenticationError: LocalizedError {
    case appleSignInFailed
    case cognitoTokenExchangeFailed
    case awsCredentialsFailed
    case userNotFound
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .appleSignInFailed:
            return "Apple Sign In failed."
        case .cognitoTokenExchangeFailed:
            return "Cognito did not accept the Apple sign-in token."
        case .awsCredentialsFailed:
            return "AWS credentials could not be created for this Apple sign-in. Check the Cognito Identity Pool Apple provider setup."
        case .userNotFound:
            return "No saved user profile was found."
        case .notImplemented:
            return "This part of authentication is not implemented yet."
        }
    }
}

/// Thrown when cloud deletion fails (account is not deleted until this is resolved).
enum AccountDeletionError: LocalizedError {
    case cloudDeletionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .cloudDeletionFailed(let err):
            if err is CredentialError {
                return "Your session has expired. Sign in again, then try deleting your account."
            }
            return "Deletion failed: your session may have expired or there was a network problem. Sign in again and try again."
        }
    }
}

