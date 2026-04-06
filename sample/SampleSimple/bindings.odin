package main

import "core:c"

foreign import wpg "../../bin/WinPdfGenerator.lib"

wpg_metadata :: struct {
	title, author, subject, keywords, creator, producer: cstring,
	creation_date, mod_date:                             cstring,
}

wpg_embedded_font :: struct {
	path, alias: cstring,
}

@(default_calling_convention = "c")
foreign wpg {
	@(link_name = "wpg_document_create")
	wpg_document_create :: proc() -> rawptr ---

	@(link_name = "wpg_document_write_to_file")
	wpg_document_write_to_file :: proc(doc: rawptr, filename: cstring) -> c.bool ---

	@(link_name = "wpg_document_close")
	wpg_document_close :: proc(doc: rawptr) ---

	@(link_name = "wpg_document_add_page")
	wpg_document_add_page :: proc(doc: rawptr, width, height: c.float) -> rawptr ---

	@(link_name = "wpg_document_add_embedded_font")
	wpg_document_add_embedded_font :: proc(doc: rawptr, embedded_font: ^wpg_embedded_font) -> c.bool ---

	@(link_name = "wpg_document_set_metadata")
	wpg_document_set_metadata :: proc(doc: rawptr, metadata_struct: ^wpg_metadata) ---

	@(link_name = "wpg_page_add_text")
	wpg_page_add_text :: proc(page: rawptr, text: cstring, x, y: c.float, font_name: cstring, font_size: c.float, text_color_rgb: [3]c.float) ---

	@(link_name = "wpg_page_add_image")
	wpg_page_add_image :: proc(page: rawptr, path: cstring, x, y, w, h: c.float) ---
}
