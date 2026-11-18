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
