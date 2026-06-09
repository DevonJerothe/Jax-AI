import Foundation

enum AppFeatures {
    #if APPSTORE
    static let characterBrowserEnabled = false
    #else 
    static let characterBrowserEnabled = true
    #endif 
}
