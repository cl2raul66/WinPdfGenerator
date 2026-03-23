package pdf_cli

import "core:c"
import "core:fmt"

foreign import winpdfgenerator "../../bin/WinPdfGenerator.lib"

foreign winpdfgenerator {
    pdf_document_create           :: proc() -> rawptr ---
    pdf_document_write_to_file    :: proc(doc: rawptr, filename: cstring) -> c.bool ---
    pdf_document_close            :: proc(doc: rawptr) ---
    page_info_builder_create_a4   :: proc(n: c.int) -> rawptr ---
    page_info_builder_build       :: proc(b: rawptr) -> rawptr ---
    page_info_free                :: proc(info: rawptr) ---
    pdf_document_start_page        :: proc(doc, info: rawptr) -> rawptr ---
    pdf_document_finish_page      :: proc(doc, page: rawptr) ---
    pdf_page_text_object_create   :: proc(text: cstring, x, y: c.float, font_name: cstring, font_size: c.float) -> rawptr ---
    pdf_page_text_object_set_color :: proc(obj: rawptr, r, g, b: c.float) ---
    pdf_page_add_text_object      :: proc(page, obj: rawptr) ---
}

main :: proc() {
    doc := pdf_document_create()
    defer pdf_document_close(doc)

    b := page_info_builder_create_a4(1)
    info := page_info_builder_build(b)
    defer page_info_free(info)

    page := pdf_document_start_page(doc, info)
    pdf_document_finish_page(doc, page)

    txt := pdf_page_text_object_create("Hola mundo desde Odin!", 72, 700, "Helvetica", 24)
    pdf_page_text_object_set_color(txt, 0.1, 0.1, 0.8)
    pdf_page_add_text_object(page, txt)

    success := pdf_document_write_to_file(doc, "bin/output_odin.pdf")
    if success {
        fmt.println("PDF generado: bin/output_odin.pdf")
    } else {
        fmt.println("Error al generar PDF")
    }
}
