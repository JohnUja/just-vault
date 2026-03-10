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
    
    // AWS Configuration
    private let userPoolId = AWSConfig.userPoolId
    private let clientId = AWSConfig.clientId
    private let identityPoolId = AWSConfig.identityPoolId
    private let region = AWSConfig.region
    
    override init() {
        super.init()
        // AWS SDK for Swift v1 will use default configuration
        // Credentials will be provided by Cognito Identity Pool after authentication
    }
    
    /// Initiate Apple Sign In flow
    func signInWithApple() async throws {
        isLoading = true
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
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let identityToken = appleIDCredential.identityToken,
                      let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                    continuation?.resume(throwing: AuthenticationError.appleSignInFailed)
                    continuation = nil
                    return
                }
                
                let appleUserID = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                // Exchange Apple token for Cognito token
                let cognitoTokens = try await exchangeAppleTokenForCognito(identityToken: identityTokenString)
                
                // Get AWS credentials from Identity Pool
                let cognitoIdentityId = try await getAWSCredentials(cognitoToken: cognitoTokens.idToken, tokens: cognitoTokens)
                
                // Create or load user
                let user = try await createOrLoadUser(
                    appleUserID: appleUserID,
                    email: email,
                    fullName: fullName,
                    cognitoIdentityId: cognitoIdentityId
                )
                
                currentUser = user
                isAuthenticated = true
                
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
        let config = try await CognitoIdentityProviderClient.CognitoIdentityProviderClientConfiguration(
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
    
    private func getAWSCredentials(cognitoToken: String, tokens: CognitoTokens) async throws -> String {
        // Get AWS credentials from Cognito Identity Pool
        // This exchanges the Cognito ID token for temporary AWS credentials
        
        // Create Cognito Identity client
        let config = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(
            region: region
        )
        let client = CognitoIdentityClient(config: config)
        
        // Create logins dictionary with the Cognito User Pool provider
        let userPoolProvider = "cognito-idp.\(region).amazonaws.com/\(userPoolId)"
        let logins: [String: String] = [userPoolProvider: cognitoToken]
        
        // Step 1: Get Identity ID
        let getIdInput = GetIdInput(
            identityPoolId: identityPoolId,
            logins: logins
        )
        
        let getIdResponse = try await client.getId(input: getIdInput)
        guard let identityId = getIdResponse.identityId else {
            throw AuthenticationError.awsCredentialsFailed
        }
        
        // Step 2: Get credentials for the identity
        let getCredentialsInput = GetCredentialsForIdentityInput(
            identityId: identityId,
            logins: logins
        )
        
        let credentialsResponse = try await client.getCredentialsForIdentity(input: getCredentialsInput)
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
                tokens: tokens
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
        
        // Synchronize to ensure data is saved
        UserDefaults.standard.synchronize()
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
        // Clear local data
        currentUser = nil
        isAuthenticated = false
        
        // Clear AWS credentials
        CredentialManager.shared.clearCredentials()
        
        // Clear local storage
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
}

// MARK: - Supporting Types

struct CognitoTokens {
    let idToken: String
    let accessToken: String
    let refreshToken: String
}

enum AuthenticationError: Error {
    case appleSignInFailed
    case cognitoTokenExchangeFailed
    case awsCredentialsFailed
    case userNotFound
    case notImplemented
}

