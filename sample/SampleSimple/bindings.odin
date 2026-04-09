package main

import "core:c"

foreign import wpg "../../bin/WinPdfGenerator.lib"

wpg_metadata_dto :: struct {
	title, author, subject, keywords, creator, producer, creation_date, mod_date: cstring,
}

wpg_embedded_font_dto :: struct {
	path, alias: cstring,
}

wpg_sig_field_dto :: struct {
	page, reserved_size: c.int,
	rect_llx, rect_lly, rect_urx, rect_ury: c.float,
	reason, location, contact: cstring,
}

wpg_security_dto :: struct {
	user_password, owner_password: cstring,
	allow_print, allow_modify, allow_copy, allow_annotate, encrypt_metadata: c.bool,
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
	wpg_document_add_embedded_font :: proc(doc: rawptr, ef_dto: ^wpg_embedded_font_dto) -> c.bool ---

	@(link_name = "wpg_document_set_metadata")
	wpg_document_set_metadata :: proc(doc: rawptr, md_dto: ^wpg_metadata_dto) ---

	@(link_name = "wpg_page_add_text")
	wpg_page_add_text :: proc(page: rawptr, text: cstring, x, y: c.float, font_name: cstring, font_size: c.float, text_color_rgb: [3]c.float) ---

	@(link_name = "wpg_page_add_image")
	wpg_page_add_image :: proc(page: rawptr, path: cstring, x, y, w, h: c.float) ---

	@(link_name = "wpg_document_add_sig_field")
	wpg_document_add_sig_field :: proc(doc: rawptr, field_dto: ^wpg_sig_field_dto) -> c.bool ---

	@(link_name = "wpg_document_patch_signature")
	wpg_document_patch_signature :: proc(pdf_buf: [^]byte, pdf_len: c.int, ph: rawptr, signature_data: [^]byte, sig_len: c.int) -> c.bool ---

	@(link_name = "wpg_document_set_security")
	wpg_document_set_security :: proc(doc: rawptr, sec_dto: ^wpg_security_dto) -> c.bool ---
}
