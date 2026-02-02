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
                let cognitoIdentityId = try await getAWSCredentials(cognitoToken: cognitoTokens.idToken)
                
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
    
    private func getAWSCredentials(cognitoToken: String) async throws -> String {
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
        guard credentialsResponse.credentials != nil else {
            throw AuthenticationError.awsCredentialsFailed
        }
        
        // Store credentials for use by AWS SDK services (S3, DynamoDB)
        // The AWS SDK for Swift v1 uses a different credential provider system
        // We'll need to configure the default credential provider chain
        // For now, we'll return the identity ID and credentials will be managed per-service
        
        // Note: In AWS SDK for Swift v1, credentials are typically managed per-client
        // We'll configure S3 and DynamoDB clients with these credentials when we implement those services
        
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
        // TODO: Load from UserDefaults or Core Data
        throw AuthenticationError.userNotFound
    }
    
    private func saveUserToLocalStorage(_ user: User) async throws {
        // TODO: Save to UserDefaults or Core Data
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        // Clear local data
        currentUser = nil
        isAuthenticated = false
        
        // Clear AWS credentials
        // TODO: Clear Cognito tokens from keychain
        
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

