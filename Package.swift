// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "ImgurAnonymousAPI",
    products: [
        .library(
            name: "ImgurAnonymousAPI",
            targets: ["ImgurAnonymousAPI"]),
    ],
    targets: [
        .target(
            name: "ImgurAnonymousAPI",
            dependencies: []),
        .testTarget(
            name: "ImgurAnonymousAPITests",
            dependencies: ["ImgurAnonymousAPI"]),
    ]
)
