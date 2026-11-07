# Changelog

All notable changes to Maske are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-11-07

Build 2: masks that fit.

- Photos taken at an angle, turned or with background now work: the document is found, straightened and turned upright before anything is read, and that straightened document is what you review and share.
- Masks follow the text exactly: fitted to the ink of the characters, at the text's own angle, with a thin margin. A value next to its label no longer takes the label with it.
- The machine-readable zone mask covers its characters only, no longer the full width of the photo.
- The portrait mask uses the portrait's own edge when it has one.
- A supported list of 27 countries (Europe, North America, Australia and New Zealand, East and Southeast Asia); documents from elsewhere get a warning to check every box.
- Known problems are listed in docs/KNOWN_ISSUES.md.

Build 1:

The first prototype, for the team to try.

- Scan with the document camera, or choose photos, an image or a PDF; front and back become one copy.
- Finds the machine-readable zone (ICAO 9303 TD1, TD2, TD3 and the ISO 18013 licence line), personal and document numbers with their check digits for about 45 national formats, labelled fields in many languages, numbered licence fields (EU model, ISO 18013, AAMVA), the card access number, addresses, faces and barcodes.
- Recognises the document's kind and country, with profiles for 50 European countries, the US, Canada, Mexico, Australia, New Zealand, China, Hong Kong, Taiwan, Japan, South Korea, Singapore, Malaysia, India and Brazil.
- Review: tap a box to show or hide it, switch a whole kind on or off, draw your own boxes.
- The shared copy: masks painted in, the recipient, purpose and date written across it, at most 1600 pixels wide, no metadata. The temporary file is deleted when you are done.
- The `maske` tool and 41 synthetic documents to check the engine.
