// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "union-phone-auth",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "UnionPhoneAuth",
            targets: ["UnionPhoneAuth"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/marmelroy/PhoneNumberKit", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "UnionPhoneAuth",
            dependencies: [
                .product(name: "PhoneNumberKit", package: "PhoneNumberKit")
            ],
            path: "Sources/UnionPhoneAuth"
        )
    ]
)
