-- =============================================================================
-- test_al32utf8.sql
--
-- Regression test for PL_FPDF on AL32UTF8 databases.
--
-- Verifies:
--   - WinAnsi conversion for PDF core fonts
--   - Euro sign
--   - accented Latin characters
--   - typographic quotes
--   - GetStringWidth with multibyte database characters
--   - Cell / MultiCell execution
--   - generation of a valid PDF BLOB
--
-- The generated PDF uses uncompressed page content so that the expected
-- WinAnsi hexadecimal strings can be inspected directly in the BLOB.
-- =============================================================================

set serveroutput on

declare
    l_pdf      blob;
    l_width    number;

    l_euro     varchar2(100) := unistr('Euro: \20AC');
    l_accents  varchar2(100) := unistr('Accents: \00E8 \00E9 \00E0 \00F9');
    l_quotes   varchar2(100) := unistr('Quotes: \2018 \2019 \201C \201D');

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
    dbms_output.put_line('PL_FPDF AL32UTF8 regression test');
    dbms_output.put_line('--------------------------------');

    PL_FPDF.fpdf('P', 'mm', 'A4');
    PL_FPDF.OpenPDF;
    PL_FPDF.SetCompression(false);
    PL_FPDF.AddPage;
    PL_FPDF.SetFont('Arial', '', 12);

    -- -------------------------------------------------------------------------
    -- Font metrics
    -- -------------------------------------------------------------------------

    l_width := PL_FPDF.GetStringWidth(l_euro);

    assert_true(
        l_width > 0,
        'GetStringWidth returned an invalid width for Euro text'
    );

    l_width := PL_FPDF.GetStringWidth(l_accents);

    assert_true(
        l_width > 0,
        'GetStringWidth returned an invalid width for accented text'
    );

    l_width := PL_FPDF.GetStringWidth(l_quotes);

    assert_true(
        l_width > 0,
        'GetStringWidth returned an invalid width for typographic quotes'
    );

    dbms_output.put_line('PASS - GetStringWidth');

    -- -------------------------------------------------------------------------
    -- Text generation
    -- -------------------------------------------------------------------------

    PL_FPDF.Cell(
        0,
        8,
        l_euro,
        0,
        1
    );

    PL_FPDF.Cell(
        0,
        8,
        l_accents,
        0,
        1
    );

    PL_FPDF.Cell(
        0,
        8,
        l_quotes,
        0,
        1
    );

    -- Exercise the MultiCell path as well.
    PL_FPDF.MultiCell(
        180,
        6,
        l_euro || ' - ' || l_accents || ' - ' || l_quotes
    );

    dbms_output.put_line('PASS - Cell / MultiCell');

    -- get_output finalizes the document automatically when necessary.
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
    -- Verify the actual bytes written for WinAnsi core fonts.
    --
    -- Expected Windows-1252 values:
    --
    --   Euro       U+20AC -> 80
    --   è          U+00E8 -> E8
    --   é          U+00E9 -> E9
    --   à          U+00E0 -> E0
    --   ù          U+00F9 -> F9
    --   ‘          U+2018 -> 91
    --   ’          U+2019 -> 92
    --   “          U+201C -> 93
    --   ”          U+201D -> 94
    --
    -- PL_FPDF emits core-font text as PDF hexadecimal strings.
    -- -------------------------------------------------------------------------

    assert_true(
        blob_contains(
            l_pdf,
            '<4575726F3A2080>'
        ),
        'Euro sign was not encoded as WinAnsi 0x80'
    );

    assert_true(
        blob_contains(
            l_pdf,
            '<416363656E74733A20E820E920E020F9>'
        ),
        'Accented characters were not encoded as expected WinAnsi bytes'
    );

    assert_true(
        blob_contains(
            l_pdf,
            '<51756F7465733A2091209220932094>'
        ),
        'Typographic quotes were not encoded as expected WinAnsi bytes'
    );

    dbms_output.put_line('PASS - WinAnsi byte encoding');

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
