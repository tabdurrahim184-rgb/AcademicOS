// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AcademicOS",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AcademicOSKit",
            targets: ["AcademicOSKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0")
    ],
    targets: [
        .target(
            name: "AcademicOSKit",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS]))
            ],
            path: "AcademicOS",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
                "App/AcademicOSApp.swift",
                "AcademicOS.entitlements",
                "Documentation"
            ]
        ),
        .testTarget(
            name: "AcademicOSTests",
            dependencies: ["AcademicOSKit"],
            path: "Tests/AcademicOSTests"
        )
    ]
)
