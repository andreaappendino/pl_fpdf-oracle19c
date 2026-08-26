# PL_FPDF for Oracle 19c

A compatibility-focused version of a legacy **PL_FPDF** codebase for **Oracle Database 19c** and **AL32UTF8** databases.

This project derives from a legacy PL_FPDF deployment by Pierre-Gilles Levallois and contributors, itself a PL/SQL port of FPDF 1.53 by Olivier Plathey.

The source has a mixed historical lineage: its original header identifies version `0.9.2` (2006), while the public `PL_FPDF_VERSION` constant reports `0.9.4`. Both details are intentionally preserved in the source rather than presenting this repository as an official upstream PL_FPDF release.

The goal of this project is deliberately conservative:

> Keep existing PL_FPDF applications working on modern Oracle databases with the minimum possible changes.

It is **not a rewrite** and does not introduce a new API.

## Why this project exists

This legacy PL_FPDF codebase was designed for older Oracle Database versions

```text
ORDSYS.ORDImage
```

Oracle Multimedia was desupported in Oracle Database 19c.

Applications migrating from older Oracle versions can therefore encounter failures when PL_FPDF tries to process images.

A second class of problems appears when migrating databases from a single-byte character set such as `WE8MSWIN1252` to `AL32UTF8`.

PL_FPDF uses the standard PDF fonts with `WinAnsiEncoding`, while the original implementation was not designed to handle AL32UTF8 strings correctly in all text and font-metric operations.

This version addresses both problems while preserving the original PL_FPDF programming model.

## Main changes

### Oracle Database 19c compatibility

- Removed the runtime dependency on `ORDSYS.ORDImage`.
- Replaced Oracle Multimedia image handling with native `BLOB` processing.
- Designed for Oracle Database 19c.

### Image handling

- Native PNG parsing.
- Native JPEG parsing.
- Direct JPEG embedding using PDF `/DCTDecode`.
- Binary-safe image streams on AL32UTF8 databases.
- Fixes for PNG predictor parameters.
- Tested with dynamically generated barcode PNG images.

### AL32UTF8 support

- Correct conversion of text used with standard PDF WinAnsi fonts.
- Fixes for accented characters and symbols such as the Euro sign.
- Fixes for multibyte character handling in font metrics.
- Fixes affecting `Cell`, `MultiCell`, `Write`, `Text` and `GetStringWidth`.

### Legacy API

Existing code using the traditional PL_FPDF API can continue to use calls such as:

```plsql
PL_FPDF.fpdf('P', 'mm', 'A4');
PL_FPDF.AddPage();
PL_FPDF.SetFont('Arial', 'B', 16);
PL_FPDF.Cell(0, 10, 'Hello World');
PL_FPDF.MultiCell(...);
PL_FPDF.Image(...);
PL_FPDF.Output('document.pdf', 'D');
```

The intention is to minimize changes to existing applications.

## Character encoding

This project supports AL32UTF8 database input when using the standard PDF fonts by converting supported characters to the encoding expected by those fonts.

The standard PDF fonts still use:

```text
WinAnsiEncoding / Windows-1252
```

Therefore this is **not a full Unicode PDF implementation**.

Western European characters such as accented Latin characters, typographic quotes and the Euro sign are supported.

Characters outside the Windows-1252 repertoire require a PDF implementation using embedded Unicode fonts.

## Known limitations

- This is not a general Unicode PDF engine.
- PNG and JPEG are supported.
- GIF/BMP conversion previously provided indirectly through `ORDSYS.ORDImage` is not supported.
- PNG Adam7/interlaced support is not provided.
- Remote image loading depends on Oracle network configuration and ACLs.
- Standard PDF fonts are not embedded and may be substituted by the PDF viewer.

## Origin

Based on:

Based on a legacy PL_FPDF codebase whose source header identifies version `0.9.2` and whose public `PL_FPDF_VERSION` constant reports `0.9.4`.

Original author: Pierre-Gilles Levallois  
Contributors: PL_FPDF contributors  
Based on FPDF 1.53 by Olivier Plathey.

The original PL_FPDF source is distributed under the GNU General Public License version 2 or later.

This derivative work retains the original licensing terms and attribution.

## Status

This project was created while migrating an existing PL_FPDF installation from an older Oracle Database environment to:

- Oracle Database 19c
- `AL32UTF8`

The compatibility changes are intended primarily for existing PL_FPDF applications facing the same migration issues.

See `CHANGELOG.md` for the detailed list of modifications.
