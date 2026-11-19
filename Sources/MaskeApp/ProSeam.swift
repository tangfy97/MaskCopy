import SwiftUI

// MaskCopy is open core. Recognition, masking, rendering and the free app are in this repository.
// MaskCopy Pro (paid workflows) is a separate, private source tree that only App Store builds compile
// in, through the conditional include in project.yml. See docs/OPEN_CORE.md.
//
// This file is the whole seam. Without Pro, `MASKCOPY_PRO` is not defined, nothing here adds anything,
// and the app is complete.

extension View {
    /// Where Pro adds its entry on Home.
    @ViewBuilder func proEntry() -> some View {
        #if MASKCOPY_PRO
        modifier(ProEntryModifier())
        #else
        self
        #endif
    }
}

/// What Pro unlocks that the free app refuses. Payslips, bank statements, bills and other documents
/// that are not identity documents are Pro; their masks are still found by the open engine.
enum ProAccess {
    @MainActor static var otherDocuments: Bool {
        #if MASKCOPY_PRO
        ProFeatures.otherDocuments
        #else
        false
        #endif
    }
}
