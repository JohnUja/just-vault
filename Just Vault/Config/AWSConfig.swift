//
//  AWSConfig.swift
//  Just Vault
//
//  AWS Configuration - Resource IDs from setup
//

import Foundation

struct AWSConfig {
    // Cognito Configuration
    static let userPoolId = "us-east-1_LWnUEtE0Q"
    static let clientId = "ci4pqvrukg5rac3oi2lqf0ge5"
    static let identityPoolId = "us-east-1:0acea479-25da-4d11-abc4-3edc6ce8f168"
    
    // AWS Region
    static let region = "us-east-1"
    
    // S3 Configuration
    static let s3BucketName = "just-vault-prod-blobs"
    
    // DynamoDB Configuration
    static let dynamoDBTableName = "JustVault"
    
    // IAM Role
    static let iamRoleArn = "arn:aws:iam::491085415425:role/JustVaultAuthenticatedUserRole"
    
    // Account ID
    static let accountId = "491085415425"
}

