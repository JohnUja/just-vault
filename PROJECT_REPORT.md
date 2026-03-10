# Just Vault: A Comprehensive Development Report

## Introduction

Just Vault represents an ambitious journey in developing a secure, user-friendly file storage application for iOS. This report chronicles the development process from initial conception through the current implementation phase, documenting the technical challenges encountered, solutions implemented, and the evolution of the project's architecture and design philosophy.

## Project Genesis and Vision

The project began with a clear vision: to create a secure vault application that allows users to store, organize, and backup their sensitive files with end-to-end encryption. The application was designed to differentiate itself through a unique hexagonal interface design, where spaces (categories for files) are arranged around a central hub, creating an intuitive and visually appealing organizational system.

From the outset, the project embraced a multi-tier subscription model—Free, Pro, and Pro+—each offering different levels of storage capacity and cloud backup capabilities. This business model necessitated careful architectural planning to support both local-only storage for free users and cloud synchronization for premium subscribers.

## Architecture and Technical Foundation

### Initial Setup and Infrastructure

The project's foundation was established through careful planning of AWS infrastructure, leveraging Amazon Cognito for authentication, S3 for encrypted file storage, and DynamoDB for metadata management. The architecture was designed with security as a paramount concern, implementing client-side encryption before any data leaves the device.

The initial project structure followed SwiftUI best practices, organizing code into clear service layers: Authentication, Encryption, Storage, and Sync services. This separation of concerns enabled modular development and testing, though it also introduced complexity in managing dependencies and state across these layers.

### Data Models and State Management

The core data models—User, Space, and VaultFile—were designed to support both local persistence and cloud synchronization. The User model tracks subscription status, storage usage, and cloud backup capabilities. Spaces represent organizational categories, while VaultFile encapsulates individual files with encryption metadata and sync status.

State management proved to be one of the more challenging aspects of development. SwiftUI's reactive paradigm required careful consideration of when and how to update UI state, particularly in asynchronous contexts involving network operations and file I/O. The ViewModel pattern was adopted to bridge the gap between the reactive UI layer and imperative service operations.

## Development Challenges and Solutions

### Challenge 1: Hexagonal Layout Implementation

One of the earliest and most persistent challenges was implementing the hexagonal grid layout. The requirement was specific: six spaces arranged around a central hexagon, with one at the top, one at the bottom, and two on each side. This required developing a custom coordinate system using hexagonal geometry.

**Solution:** A `HexCoordinate` system was implemented using axial coordinates (q, r), which naturally represent hexagonal grids. The `SpacesHiveView` component calculates positions for each space based on ring positions around the center, ensuring proper alignment with hexagon faces. Multiple iterations were required to achieve the exact positioning requested, with adjustments to hexagon size and spacing to create the desired horizontal spread.

### Challenge 2: File Upload and Security-Scoped Resources

File upload functionality encountered persistent issues related to iOS's security-scoped resource system. When users selected files through `UIDocumentPickerViewController`, the app received temporary access that expired once the picker dismissed, causing files to become inaccessible.

**Solution:** The `DocumentPicker` implementation was modified to explicitly start accessing security-scoped resources, copy files to a temporary directory within the app's sandbox, and then stop accessing the resource. This ensures persistent access to file data while respecting iOS security boundaries. The solution required careful error handling and cleanup to prevent resource leaks.

### Challenge 3: AWS Credentials Management

Pro members experienced "AWS credentials failed" errors, preventing cloud backup functionality. The issue stemmed from credential expiration (default 1-hour lifetime) and insufficient refresh logic.

**Solution:** The `CredentialManager` was enhanced with a 5-minute buffer before expiration checks, allowing proactive credential refresh. Developer mode was implemented to bypass credential checks for testing purposes. Additionally, better error handling and logging were added to diagnose credential issues in production.

### Challenge 4: UI Consistency and Design System

Throughout development, maintaining visual consistency proved challenging as different views were implemented by different developers or at different times. Color schemes, particularly the transition from orange to purple/pink branding, required systematic updates across multiple files.

**Solution:** A comprehensive audit was conducted to standardize backgrounds, outlines, and accent colors. All backgrounds were unified to use a bright purple/pink + white gradient mix, with bright purple/pink outlines (`Color(red: 0.8, green: 0.4, blue: 0.9)`) for interactive elements. This created a cohesive visual language throughout the application.

### Challenge 5: Compilation Errors and Scope Issues

Recent compilation errors revealed scope and structure issues in `VaultHomeView.swift`. The errors included "Cannot find 'viewModel' in scope" and "Extraneous '}' at top level," indicating problems with async function context and brace matching.

**Solution:** The `importFileToSpace` function, while correctly placed inside the struct, required explicit main actor context for UI updates. The fix involved wrapping `viewModel.refreshSpaces()` in `await MainActor.run { }` to ensure proper thread context and scope resolution. This resolved the cascading errors that were confusing the Swift parser.

## Design Evolution

### From Orange to Purple/Pink

The application's color scheme underwent a significant evolution. Initially, orange was chosen for its warmth and differentiation from typical security app blue/purple palettes. However, user feedback and design refinement led to a shift toward bright purple/pink gradients, which better conveyed the premium, secure nature of the application while maintaining visual appeal.

This transition required updates across dozens of files, including paywall views, settings pages, backup bars, and various UI components. The systematic nature of this change highlighted the importance of maintaining a centralized design system, a lesson that informed subsequent development practices.

### Hexagon Visual Design

The hexagonal elements evolved from simple white shapes with black text to sophisticated translucent blue-green glowing elements. This change required implementing custom gradients, border glows, and shadow effects to create depth and visual interest. The final design features translucent fills with blue-green tints and glowing outlines, creating a futuristic, secure aesthetic that aligns with the application's purpose.

### Typography and Spacing

Typography consistency was achieved through systematic font size standardization: 20pt bold for main titles, 14-16pt for body text, and 10-12pt for labels. Spacing was refined to create better visual hierarchy, with "My Vault" text moved higher on the screen and consistent padding applied throughout.

## Feature Implementation Journey

### Pre-Defined Spaces

A significant pivot occurred when the decision was made to move from user-created spaces to six pre-defined spaces (Documents, Photos, Keys, Cards, Folders, and Cloud). This change simplified the user experience but required refactoring the space creation logic and ensuring default spaces are created on first launch.

The implementation involved creating a `DefaultSpacesService` that defines the six spaces with their icons, colors, and lock overlay requirements. The `VaultHomeViewModel` was updated to check for default spaces on first launch and create them if missing, with proper synchronization between local storage and DynamoDB.

### Sync Indicator System

The center hexagon's sync indicator underwent multiple iterations to achieve the desired behavior. The final implementation displays:
- Red dot: Not backed up/error state
- Yellow dot: Syncing/pending state  
- Green dot: Synced to cloud

The indicator includes a pulsing animation and status text, providing clear feedback about backup status. The implementation required careful state management to track sync status across multiple files and spaces.

### Login Screen Enhancement

The login screen was redesigned to include plan selection before sign-up, with scrollable plan cards, monthly/yearly toggle, and immediate purchase flow integration (pending StoreKit implementation). The default selection is Pro Yearly with a "RECOMMENDED" badge, guiding users toward the best value option.

## Technical Insights and Lessons Learned

### SwiftUI and Async/Await

Working with SwiftUI's reactive paradigm alongside async/await introduced complexity in managing state updates. The key lesson learned was the importance of explicitly managing main actor context for UI updates, particularly in async functions that interact with view models.

### Error Handling and User Feedback

The project emphasized robust error handling, particularly for network operations and file I/O. However, balancing detailed error logging with user-friendly error messages proved challenging. The solution involved layered error handling: detailed logging for debugging, user-friendly messages for UI, and graceful degradation when cloud services are unavailable.

### Testing and Quality Assurance

Throughout development, the importance of comprehensive testing became evident. Issues with hexagon positioning, file uploads, and credential management might have been caught earlier with more extensive testing. This realization led to the implementation of developer mode, which allows bypassing certain checks for testing purposes.

## Current State and Remaining Work

### Completed Features

The application now includes:
- Complete hexagonal layout with six pre-defined spaces
- File import and encryption functionality
- Local storage for all users
- Cloud backup infrastructure for Pro/Pro+ users
- Sync status indicators and management
- Settings and recovery options
- Paywall and subscription management UI
- Developer mode for testing

### Pending Implementation

Several features remain to be completed:
- StoreKit purchase flow integration with login screen plan selection
- Search functionality across files and spaces
- File management operations (move, multi-select, batch delete)
- Last synced time tracking and display
- Enhanced loading screen with Just™ branding
- Comprehensive error recovery and retry mechanisms

### Known Issues

- AWS credential refresh needs further refinement for production reliability
- File preview functionality requires additional testing across file types
- Space context menu features (edit, lock, delete) need full implementation
- Pagination for Pro users with more than six spaces needs verification

## Conclusion

The development of Just Vault has been a journey of iterative refinement, technical problem-solving, and design evolution. The project demonstrates the complexity of building a secure, cloud-enabled mobile application while maintaining a polished user experience.

Key achievements include a unique hexagonal interface design, robust encryption and storage systems, and a scalable architecture supporting multiple subscription tiers. The challenges encountered—from hexagonal geometry to security-scoped resources to state management—have provided valuable lessons that inform both the current implementation and future development.

As the project moves toward completion, the foundation is solid, the architecture is sound, and the user experience is taking shape. The remaining work focuses on polish, integration, and comprehensive testing to ensure a production-ready application that delivers on its promise of secure, intuitive file management.

The journey continues, with each challenge overcome and each feature implemented bringing the application closer to its vision of being the premier secure file vault for iOS users.

---

*This report documents the development journey through [current date]. For the most up-to-date status, refer to the project's issue tracker and recent commit history.*

