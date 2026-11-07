# Changelog

All notable changes to Maske are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-11-07

The first prototype, for the team to try.

- Scan with the document camera, or choose photos, an image or a PDF; front and back become one copy.
- Finds the machine-readable zone (ICAO 9303 TD1, TD2, TD3 and the ISO 18013 licence line), personal and document numbers with their check digits for about 45 national formats, labelled fields in many languages, numbered licence fields (EU model, ISO 18013, AAMVA), the card access number, addresses, faces and barcodes.
- Recognises the document's kind and country, with profiles for 50 European countries, the US, Canada, Mexico, Australia, New Zealand, China, Hong Kong, Taiwan, Japan, South Korea, Singapore, Malaysia, India and Brazil.
- Review: tap a box to show or hide it, switch a whole kind on or off, draw your own boxes.
- The shared copy: masks painted in, the recipient, purpose and date written across it, at most 1600 pixels wide, no metadata. The temporary file is deleted when you are done.
- The `maske` tool and 41 synthetic documents to check the engine.
