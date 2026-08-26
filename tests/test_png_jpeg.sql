-- =============================================================================
-- test_png_jpeg.sql
--
-- Regression test for native PNG/JPEG handling on Oracle Database 19c.
--
-- Usage:
--
--   @test_png_jpeg.sql http://host/test.png http://host/test.jpg
--
-- Use direct HTTP URLs returning the actual image body.
-- HTTPS is intentionally not tested by this compatibility release.
-- =============================================================================

set serveroutput on
set verify off

define PNG_URL  = '&1'
define JPEG_URL = '&2'

declare
    l_pdf       blob;
    l_png_url   varchar2(2000) := '&&PNG_URL';
    l_jpeg_url  varchar2(2000) := '&&JPEG_URL';

    procedure assert_true(
        p_condition boolean,
        p_message   varchar2
    ) is
    begin
        if not p_condition then
            raise_application_error(
                -20001,
                'TEST FAILED: ' || p_message
            );
        end if;
    end assert_true;

    function blob_contains(
        p_blob blob,
        p_text varchar2
    ) return boolean is
    begin
        return dbms_lob.instr(
                   p_blob,
                   utl_raw.cast_to_raw(p_text)
               ) > 0;
    end blob_contains;

begin
    dbms_output.put_line('PL_FPDF PNG/JPEG regression test');
    dbms_output.put_line('--------------------------------');

    dbms_output.put_line('PNG : ' || l_png_url);
    dbms_output.put_line('JPEG: ' || l_jpeg_url);

    PL_FPDF.fpdf('P', 'mm', 'A4');
    PL_FPDF.OpenPDF;
    PL_FPDF.SetCompression(false);

    -- -------------------------------------------------------------------------
    -- PNG
    -- -------------------------------------------------------------------------

    PL_FPDF.AddPage;

    PL_FPDF.Image(
        l_png_url,
        20,
        20,
        80
    );

    dbms_output.put_line('PASS - PNG parsed');

    -- -------------------------------------------------------------------------
    -- JPEG
    -- -------------------------------------------------------------------------

    PL_FPDF.AddPage;

    PL_FPDF.Image(
        l_jpeg_url,
        20,
        20,
        80
    );

    dbms_output.put_line('PASS - JPEG parsed');

    -- -------------------------------------------------------------------------
    -- Generate PDF
    -- -------------------------------------------------------------------------

    l_pdf := PL_FPDF.get_output;

    assert_true(
        l_pdf is not null
        and dbms_lob.getlength(l_pdf) > 0,
        'Generated PDF BLOB is empty'
    );

    assert_true(
        utl_raw.cast_to_varchar2(
            dbms_lob.substr(l_pdf, 4, 1)
        ) = '%PDF',
        'Generated BLOB does not start with %PDF'
    );

    dbms_output.put_line('PASS - PDF generated');

    -- -------------------------------------------------------------------------
    -- PNG stream
    --
    -- PNG IDAT data is already Flate-compressed.
    -- The compatibility patch ASCIIHex-encodes binary data before storing it
    -- in the legacy VARCHAR2 PDF buffer.
    -- -------------------------------------------------------------------------

    assert_true(
        blob_contains(
            l_pdf,
            '/Filter [/ASCIIHexDecode /FlateDecode]'
        ),
        'PNG image stream does not contain the expected filters'
    );

    dbms_output.put_line('PASS - PNG PDF stream');

    -- -------------------------------------------------------------------------
    -- JPEG stream
    --
    -- JPEG data must be embedded directly using DCTDecode, preceded by
    -- ASCIIHexDecode for binary-safe storage in the legacy PDF buffer.
    -- -------------------------------------------------------------------------

    assert_true(
        blob_contains(
            l_pdf,
            '/Filter [/ASCIIHexDecode /DCTDecode]'
        ),
        'JPEG image stream does not contain the expected filters'
    );

    dbms_output.put_line('PASS - JPEG PDF stream');

    dbms_output.put_line('--------------------------------');
    dbms_output.put_line('ALL TESTS PASSED');

    if dbms_lob.istemporary(l_pdf) = 1 then
        dbms_lob.freetemporary(l_pdf);
    end if;

    PL_FPDF.resetWpdf;

exception
    when others then
        if l_pdf is not null
           and dbms_lob.istemporary(l_pdf) = 1 then
            dbms_lob.freetemporary(l_pdf);
        end if;

        begin
            PL_FPDF.resetWpdf;
        exception
            when others then
                null;
        end;

        raise;
end;
/

undefine PNG_URL
undefine JPEG_URL
