
import SwiftUI

  

//======================================

// MARK: - About & Patch Log (v0.2)

//======================================

//

// Purpose:

// - Show PATCHLOG.md bundled with the app (Markdown rendered in-place).

// - Provides a simple “About” screen without any persistence dependencies.

//

// Notes:

// - PATCHLOG.md must be included in the app target's bundle resources.

// - Rendering uses `Text(.init(markdown))` which supports basic Markdown.

// - This screen is intentionally simple; richer formatting can come later.

//======================================

  

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private let markdown: String

    init() {

        self.markdown = AboutView.loadPatchlogMarkdown() ?? AboutView.fallbackMarkdown

    }

    var body: some View {

        NavigationView {

            ScrollView {

                // Text(.init(...)) renders basic Markdown

                Text(.init(markdown))

                    .frame(maxWidth: .infinity, alignment: .leading)

                    .padding()

            }

            .navigationTitle("About & Patch Log")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Close") { dismiss() }

                }

            }

        }

    }

}

  

// MARK: - Helpers

private extension AboutView {

    static func loadPatchlogMarkdown() -> String? {

        guard let url = Bundle.main.url(forResource: "PATCHLOG", withExtension: "md"),

              let data = try? Data(contentsOf: url),

              let text = String(data: data, encoding: .utf8)

        else {

            return nil

        }

        return text

    }

    static let fallbackMarkdown: String = """

    # Driver Assistant

    Patch log not found in bundle.

    Make sure PATCHLOG.md is in the app target’s **Resources**.

    """

}
