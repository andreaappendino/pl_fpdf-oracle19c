-- =============================================================================
-- test_barcode_png.sql
--
-- Regression test for indexed 1-bit PNG images such as barcodes.
--
-- Usage:
--
--   @test_barcode_png.sql http://host/barcode.png
--
-- The supplied PNG should be:
--
--   - indexed/palette based
--   - 1 bit per component
--   - non-interlaced
--
-- This test specifically verifies the DecodeParms fix required when
-- ASCIIHexDecode is prepended to FlateDecode.
-- =============================================================================

set serveroutput on
set verify off

define BARCODE_URL = '&1'

declare
    l_pdf          blob;
    l_barcode_url  varchar2(2000) := '&&BARCODE_URL';

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
    dbms_output.put_line('PL_FPDF indexed PNG / barcode regression test');
    dbms_output.put_line('---------------------------------------------');
    dbms_output.put_line('Barcode: ' || l_barcode_url);

    PL_FPDF.fpdf('P', 'mm', 'A4');
    PL_FPDF.OpenPDF;
    PL_FPDF.SetCompression(false);
    PL_FPDF.AddPage;

    PL_FPDF.Image(
        l_barcode_url,
        20,
        20,
        160
    );

    dbms_output.put_line('PASS - barcode PNG parsed');

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

    -- Indexed PNG must use an Indexed RGB color space.
    assert_true(
        blob_contains(
            l_pdf,
            '/ColorSpace [/Indexed /DeviceRGB'
        ),
        'PNG is not represented as an indexed color image'
    );

    dbms_output.put_line('PASS - indexed color space');

    -- This regression test specifically targets 1-bit barcode PNGs.
    assert_true(
        blob_contains(
            l_pdf,
            '/BitsPerComponent 1'
        ),
        'PNG is not a 1-bit image'
    );

    dbms_output.put_line('PASS - 1-bit PNG');

    -- Binary PNG data is ASCIIHex encoded before the original Flate stream.
    assert_true(
        blob_contains(
            l_pdf,
            '/Filter [/ASCIIHexDecode /FlateDecode]'
        ),
        'Expected PNG filter chain not found'
    );

    dbms_output.put_line('PASS - PNG filter chain');

    -- Critical regression:
    --
    -- DecodeParms must be an ARRAY because there are two filters.
    --
    -- Correct:
    --
    -- /Filter [/ASCIIHexDecode /FlateDecode]
    -- /DecodeParms [null <</Predictor 15 ...>>]
    --
    -- Incorrect old form:
    --
    -- /DecodeParms <</Predictor 15 ...>>
    --
    assert_true(
        blob_contains(
            l_pdf,
            '/DecodeParms [null <</Predictor 15'
        ),
        'DecodeParms are not aligned with the two-filter chain'
    );

    dbms_output.put_line('PASS - DecodeParms filter alignment');

    assert_true(
        blob_contains(
            l_pdf,
            '/Colors 1 /BitsPerComponent 1 /Columns'
        ),
        'Expected 1-bit PNG predictor parameters not found'
    );

    dbms_output.put_line('PASS - PNG predictor parameters');

    dbms_output.put_line('---------------------------------------------');
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

undefine BARCODE_URL
