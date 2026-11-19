# Privacy Policy

*Last updated: 19 November 2026 (MaskCopy Pro packs and register)*

MaskCopy is an iPhone app for sharing a copy of an identity document with parts of it hidden, made by TangSpark.

**MaskCopy collects no data.** Its code contains no networking of its own (an in-app purchase goes through Apple, see below), and it has no accounts, analytics, telemetry, crash reporting, advertising or third-party code. Unlike a Mac app, an iPhone app cannot be barred from the internet by the system, so this is a promise about MaskCopy's code, which is open source for anyone to check.

What MaskCopy does on your iPhone:

- It uses the camera only while you scan a document, and photos and files only when you choose them.
- It reads the document with Apple's Vision framework on your iPhone to find the parts to hide: text, faces and barcodes, including values beside bilingual field labels. Nothing is sent anywhere to do this.
- PDFs and scans with more than four pages open a page chooser; only the pages you select are processed. The source remains available in memory or through temporary system file access until selection finishes. MaskCopy creates no unredacted temporary source files.
- It keeps the document and its preview in memory while you review it. It writes a temporary JPG or PDF only when you choose Save or Share. Save opens the system Files picker; the copy remains at the destination you choose until you delete it. Temporary working copies are queued for deletion when you finish, leave the document, start again, or next open MaskCopy. Cleanup and export writes share a serial background queue. The free app keeps no history.
- The copy it makes has the hidden parts painted over with an opaque fill. The recipient, purpose and date form a translucent diagonal watermark inside every document page. You can move it separately on each page before exporting. Red lettering is blended with the document to preserve dark printing; light lettering keeps the watermark visible over opaque masks. JPG and PDF contain only the flattened copy, with no source photo metadata such as location or camera details. PDF contains a single image page, without text layers, annotations or a metadata dictionary.
- While a document is open, MaskCopy covers it when you switch apps, so it doesn't show in the app switcher.
- MaskCopy Pro is an optional in-app purchase handled by Apple. MaskCopy asks Apple's StoreKit on your iPhone whether Pro was bought; Apple verifies the purchase, and MaskCopy never sees your name, Apple Account or payment details. MaskCopy has no server and keeps no account. Pro works offline like the rest of the app.
- With MaskCopy Pro you can put several finished copies in a pack and share them as one PDF. The pack is kept in memory only, never written to storage until you save or share it, and is gone when MaskCopy quits or you empty it.
- MaskCopy Pro keeps a list of shared copies on your iPhone: the date, the recipient and purpose you typed, which kinds of document went out and how many pages. It never stores the document or its pictures. The list is saved in a file protected until your iPhone is unlocked, opens with Face ID or your passcode, and you can delete any line. If you ask for a reminder, MaskCopy schedules a local notification on your iPhone; it is never sent anywhere.
- It remembers one number on your iPhone: which version of its short introduction tour you have seen, so the tour shows once after installing and once after each update that adds something.

Where the copy goes after you share it is up to you and the app you share it with.

MaskCopy is suitable for all ages and collects nothing from anyone, including children. Questions: [support@tang-spark.no](mailto:support@tang-spark.no).
