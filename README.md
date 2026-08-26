# PL_FPDF for Oracle 19c

A compatibility-focused version of a legacy **PL_FPDF** codebase for **Oracle Database 19c** and **AL32UTF8** databases.

This project derives from a legacy PL_FPDF deployment by Pierre-Gilles Levallois and contributors, itself a PL/SQL port of FPDF 1.53 by Olivier Plathey.

The source has a mixed historical lineage: its original header identifies version `0.9.2` (2006), while the public `PL_FPDF_VERSION` constant reports `0.9.4`.

Both details are intentionally preserved in the source rather than presenting this repository as an official upstream PL_FPDF release.

The goal of this project is deliberately conservative:

> Keep existing PL_FPDF applications working on modern Oracle databases with the minimum possible changes.

It is **not a rewrite** and does not introduce a new API.

## Why this project exists

This legacy PL_FPDF codebase was designed for older Oracle Database versions and relied on Oracle Multimedia, in particular:

```text
ORDSYS.ORDImage
```

Oracle Multimedia was desupported in Oracle Database 19c.

Applications migrating from older Oracle versions can therefore encounter failures when PL_FPDF tries to process images.

A second class of problems appears when migrating a database from a single-byte character set such as:

```text
WE8MSWIN1252
```

to:

```text
AL32UTF8
```

PL_FPDF uses standard PDF fonts with `WinAnsiEncoding`.

The original implementation was not designed to handle AL32UTF8 strings correctly in all PDF text and font-metric operations. This can result in corrupted characters, incorrect widths or runtime errors when using characters such as accented letters, typographic punctuation or the Euro sign.

This compatibility version addresses both problems while preserving the existing PL_FPDF programming model.

## Main changes

### Oracle Database 19c compatibility

- Removed the runtime dependency on `ORDSYS.ORDImage`.
- Replaced Oracle Multimedia image handling with native `BLOB` processing.
- Removed the need for Oracle Multimedia image conversion.
- Designed for Oracle Database 19c.

### PNG support

PNG files are parsed directly from their binary `BLOB` representation.

The compatibility code handles the PNG structures required by PL_FPDF, including:

- PNG signature validation
- `IHDR`
- `PLTE`
- `tRNS`
- `IDAT`
- grayscale images
- RGB images
- indexed/palette images
- bit depths up to 8 bits
- binary-safe PDF image streams

The patch also fixes PDF predictor parameters when PNG data is combined with multiple PDF filters.

This includes support for 1-bit indexed PNG images such as dynamically generated barcodes.

### JPEG support

JPEG files are handled without Oracle Multimedia.

JPEG data is embedded directly in the generated PDF using:

```text
/DCTDecode
```

Both baseline and progressive JPEG SOF markers are recognized by the image parser.

### AL32UTF8 support

PDF core fonts still use:

```text
WinAnsiEncoding / Windows-1252
```

On an `AL32UTF8` Oracle database, PL_FPDF therefore converts supported characters to their Windows-1252 byte representation before writing them into the PDF.

Text is emitted using hexadecimal PDF strings so that those bytes are not modified by the database character-set conversion.

This fixes characters such as:

```text
€ è é à ù ‘ ’ “ ”
```

The changes affect the relevant text and metric paths, including:

```text
Cell
MultiCell
Write
Text
TextWithDirection
TextWithRotation
GetStringWidth
```

Font-width lookup was also changed so that multibyte database characters are correctly mapped to the corresponding WinAnsi font metrics.

## Character encoding limitations

This project is **not a full Unicode PDF implementation**.

It allows applications running on an `AL32UTF8` Oracle database to correctly use characters supported by Windows-1252 with the standard PDF core fonts.

For example:

```text
€
è é à ù
ñ
ö ü ä
‘ ’
“ ”
```

Characters outside the Windows-1252 repertoire are not supported by the core-font implementation.

Applications requiring arbitrary Unicode text should use a PDF solution with embedded Unicode fonts.

## Legacy API compatibility

The intention of this project is to preserve existing PL_FPDF applications.

Typical legacy code can continue to use the familiar API:

```plsql
PL_FPDF.fpdf('P', 'mm', 'A4');

PL_FPDF.OpenPDF;
PL_FPDF.AddPage();

PL_FPDF.SetFont('Arial', 'B', 16);

PL_FPDF.Cell(
    0,
    10,
    'Hello World'
);

PL_FPDF.MultiCell(
    180,
    6,
    'Some longer text'
);

PL_FPDF.Output(
    'document.pdf',
    'D'
);
```

Existing applications should generally not need to be rewritten around a new PDF API.

## Installation

Run:

```text
PL_FPDF.pck
```

in the Oracle schema where the package should be installed.

The file contains both the package specification and package body.

After installation, verify that both objects are valid:

```sql
select object_name,
       object_type,
       status
  from user_objects
 where object_name = 'PL_FPDF';
```

Expected result:

```text
PL_FPDF   PACKAGE        VALID
PL_FPDF   PACKAGE BODY   VALID
```

## AL32UTF8 regression test

The repository contains:

```text
tests/test_al32utf8.sql
```

The test verifies:

- `GetStringWidth` with multibyte database characters
- `Cell`
- `MultiCell`
- PDF BLOB generation
- PDF header generation
- actual Windows-1252 bytes emitted into the PDF
- Euro sign encoding
- accented-character encoding
- typographic-quote encoding

Run the test on an Oracle 19c database with the package installed.

A successful execution produces:

```text
PL_FPDF AL32UTF8 regression test
--------------------------------
PASS - GetStringWidth
PASS - Cell / MultiCell
PASS - PDF generated
PASS - WinAnsi byte encoding
--------------------------------
ALL TESTS PASSED
```

This test has been successfully executed against the compatibility package on an Oracle Database 19c / AL32UTF8 environment.

## Remote images

Remote image loading retains the legacy PL_FPDF approach and currently uses Oracle `URIType`.

HTTP URLs and legacy relative URLs therefore depend on the Oracle Database network configuration and ACLs.

For example:

```plsql
PL_FPDF.Image(
    'http://example.org/image.png',
    10,
    10,
    50
);
```

Relative URLs are resolved using the web-server environment exposed through the Oracle Web Toolkit.

### HTTPS

HTTPS URL loading is **not guaranteed on Oracle Database 19c** with the current `URIType` implementation.

HTTPS should therefore be considered unsupported by this compatibility release unless it has been independently verified in the target Oracle environment.

A future implementation could replace the legacy URL retrieval mechanism with `UTL_HTTP`, but that is intentionally outside the scope of the current compatibility patch.

## Known limitations

- This is not a general Unicode PDF engine.
- Core fonts remain limited to `WinAnsiEncoding`.
- Characters outside Windows-1252 are not supported by the core-font text path.
- PNG and JPEG are supported.
- GIF and BMP conversion previously provided indirectly through `ORDSYS.ORDImage` is not supported.
- Interlaced/Adam7 PNG images are not supported.
- PNG support is limited to the image types handled by the native parser.
- Remote HTTP images depend on Oracle network configuration and ACLs.
- HTTPS remote-image loading is not guaranteed.
- Standard PDF fonts are not embedded and may be substituted by the PDF viewer.

## Design philosophy

This repository intentionally avoids turning PL_FPDF into a new PDF framework.

The objective is:

```text
existing PL_FPDF application
        +
Oracle Database 19c
        +
AL32UTF8
        =
minimum required changes
```

In particular, this project does not attempt to add a new document model, template engine or general-purpose Unicode font system.

It is a compatibility patch for applications that already depend on PL_FPDF.

## Origin

This project is based on a legacy PL_FPDF codebase whose source header identifies version `0.9.2` and whose public `PL_FPDF_VERSION` constant reports `0.9.4`.

Original author:

**Pierre-Gilles Levallois**

PL_FPDF itself is a PL/SQL port of **FPDF 1.53** by Olivier Plathey.

The historical version information and original attribution have been retained in the package source.

## License

The original PL_FPDF source is distributed under the **GNU General Public License version 2 or later**.

This derivative work retains the original licensing terms and attribution.

See:

```text
LICENSE.md
```

for the complete license text.

## Changelog

See:

```text
CHANGELOG.md
```

for the detailed list of Oracle 19c, image-processing and AL32UTF8 compatibility changes.

## Project status

The package is being maintained as a compatibility solution for legacy PL_FPDF applications migrated to:

```text
Oracle Database 19c
AL32UTF8
```

The AL32UTF8 regression test included in this repository currently passes successfully.

Additional regression tests for PNG and JPEG image handling are being added separately.
