# Changelog

All notable changes to this Oracle 19c compatibility version of PL_FPDF are documented here.

This project is based on **PL_FPDF 0.9.4**.

## [0.9.4-oracle19c-1] - 2026-08-26

### Oracle Database 19c compatibility

- Removed the runtime dependency on `ORDSYS.ORDImage`.
- Replaced Oracle Multimedia image handling with native `BLOB` processing.
- Added native image parsing for PNG and JPEG files.
- Preserved the existing `PL_FPDF.Image` API as much as possible.

### PNG support

- Added native PNG signature and chunk parsing.
- Added support for `IHDR`, `PLTE`, `tRNS` and `IDAT` data required by the PDF image stream.
- Added binary-safe image handling suitable for AL32UTF8 databases.
- Fixed PDF `/DecodeParms` association when PNG data is combined with multiple PDF filters.
- Fixed rendering of 1-bit indexed PNG images such as dynamically generated barcodes.

### JPEG support

- Added native JPEG detection and metadata parsing.
- JPEG data is embedded directly in the PDF using `/DCTDecode`.
- Removed the need for Oracle Multimedia to decode or convert JPEG files.

### AL32UTF8 compatibility

- Fixed PDF text generation when the database character set is `AL32UTF8` and standard PDF fonts use `WinAnsiEncoding`.
- Text supported by Windows-1252 is converted to the byte representation expected by the PDF core fonts.
- PDF text strings are emitted in a binary-safe hexadecimal representation where required.
- Fixed handling of characters such as accented Latin letters, typographic punctuation and the Euro sign.

### Font metrics

- Fixed font metric lookup for multibyte database characters.
- Removed assumptions that a PL/SQL `VARCHAR2(1)` value always occupies one byte.
- Fixed an `ORA-06502` failure affecting text containing multibyte characters on AL32UTF8 databases.
- Updated width calculations used by text layout functions.

### Text and layout

Encoding and metric fixes were applied to the relevant text paths, including:

- `Cell`
- `MultiCell`
- `Write`
- `Text`
- `TextWithDirection`
- `TextWithRotation`
- `GetStringWidth`

Page-count alias handling was also adjusted to work with the new PDF text representation.

### BLOB handling

- Fixed BLOB stream writing at chunk boundaries.
- Image binary data is no longer passed through database character-set conversions.
- PNG and JPEG streams are written to the PDF in a character-set-safe form.

### Compatibility

The objective of this release is to preserve the PL_FPDF 0.9.4 programming model.

Existing applications should generally continue to use calls such as:

    PL_FPDF.fpdf('P', 'mm', 'A4');
    PL_FPDF.AddPage();
    PL_FPDF.SetFont('Arial', 'B', 16);
    PL_FPDF.Cell(...);
    PL_FPDF.MultiCell(...);
    PL_FPDF.Image(...);
    PL_FPDF.Output(...);

### Known limitations

- This is not a full Unicode PDF implementation.
- Standard PDF fonts continue to use `WinAnsiEncoding`.
- Characters outside the Windows-1252 repertoire require a different font/encoding solution.
- PNG and JPEG are supported.
- GIF and BMP conversion previously supplied indirectly by `ORDSYS.ORDImage` is not provided by this compatibility patch.
- Remote URL image loading depends on the Oracle Database network configuration and may require network ACL and HTTPS/wallet configuration.
