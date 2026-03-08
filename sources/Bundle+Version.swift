
import Foundation

  

//======================================

// MARK: - Bundle+Version.swift

//======================================

// 

// potentially redundant file . meant to provide version number when patchlog unavailable.

  

  

extension Bundle {

    /// CFBundleShortVersionString (e.g. "0.2.1")

    var releaseVersionNumber: String {

        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

    }

    /// CFBundleVersion (e.g. "103")

    var buildVersionNumber: String {

        infoDictionary?["CFBundleVersion"] as? String ?? "—"

    }

}
