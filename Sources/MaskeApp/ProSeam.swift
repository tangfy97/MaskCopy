import os
import SwiftUI

// MaskCopy is open core. Recognition, masking, rendering and the free app are in this repository.
// MaskCopy Pro (paid workflows) is a separate, private source tree that only App Store builds compile
// in, through the conditional include in project.yml. See docs/OPEN_CORE.md.
//
// This file is the whole seam. Without Pro, `MASKCOPY_PRO` is not defined, nothing here adds anything,
// and the app is complete.

extension View {
    /// Applied once on Home: Pro reads what was bought when the app opens.
    @ViewBuilder func proEntry() -> some View {
        #if MASKCOPY_PRO
        modifier(ProEntryModifier())
        #else
        self
        #endif
    }
}

/// The Pro row on the Documents page (purchase, restore). Nothing without Pro.
struct ProSection: View {
    var body: some View {
        #if MASKCOPY_PRO
        ProInfoSection()
        #endif
    }
}

/// Pro's place at the bottom of Home. Nothing without Pro.
struct ProHomeEntry: View {
    var body: some View {
        #if MASKCOPY_PRO
        ProHomeCapsule()
        #endif
    }
}

/// What the app shows instead of a document the free app refuses, in builds that can sell Pro.
struct ProRefusal: View {
    let chooseAnother: () -> Void
    var body: some View {
        #if MASKCOPY_PRO
        ProRefusalView(chooseAnother: chooseAnother)
        #endif
    }
}

/// A mark beside the screen title while a Pro document is open. Nothing without Pro.
struct ProTitleBadge: View {
    let isProDocument: Bool
    var body: some View {
        #if MASKCOPY_PRO
        if isProDocument { ProSeal() }
        #endif
    }
}

/// Pro's page at the end of the tour. None without Pro.
enum ProTour {
    static var pages: [Tour.Page] {
        #if MASKCOPY_PRO
        [Tour.Page(id: "pro", scene: .pro, title: Text("Payslips and bank statements"), detail: Text("MaskCopy Pro"))]
        #else
        []
        #endif
    }
}

/// The picture on Pro's tour page. Nothing without Pro.
struct ProTourScene: View {
    let active: Bool
    var body: some View {
        #if MASKCOPY_PRO
        ProTourPicture(active: active)
        #endif
    }
}

/// Pro's actions on the finished copy (add it to a pack). Nothing without Pro.
struct ProCopyActions: View {
    var body: some View {
        #if MASKCOPY_PRO
        ProCopyActionsView()
        #endif
    }
}

/// Pro's button at the top left of Home (the copy register). Nothing without Pro.
struct ProHomeToolbar: View {
    var body: some View {
        #if MASKCOPY_PRO
        ProRegisterButton()
        #endif
    }
}

/// Told when a copy has been saved or shared, so Pro can note it in its on-device register.
enum ProEvents {
    @MainActor static func copyExported(session: Session) {
        #if MASKCOPY_PRO
        ProRegister.shared.record(session: session)
        #endif
    }
}

/// What Pro unlocks that the free app refuses. Payslips, bank statements, bills and other documents
/// that are not identity documents are Pro; their masks are still found by the open engine.
/// Observable, so screens update the moment a purchase or refund lands.
@MainActor @Observable
final class ProAccess {
    static let shared = ProAccess()
    var otherDocuments = false
    /// Recipient and purpose a new document starts with (a Pro pack in progress); empty otherwise.
    var defaultRecipient = ""
    var defaultPurpose = ""
    /// Whether this build can sell Pro at all (it can't without the private tree).
    nonisolated static var canUnlock: Bool {
        #if MASKCOPY_PRO
        true
        #else
        false
        #endif
    }
    private init() {}
}

/// Limits Pro raises. Read off the main thread while importing, so kept behind a lock.
enum ProLimits {
    static let freePages = 4
    private static let pages = OSAllocatedUnfairLock(initialState: freePages)
    static var maximumPages: Int { pages.withLock { $0 } }
    static func setMaximumPages(_ count: Int) { pages.withLock { $0 = count } }
}
