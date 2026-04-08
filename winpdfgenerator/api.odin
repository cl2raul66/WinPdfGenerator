package winpdfgenerator

import "core:c"
import "base:runtime"

@(export)
wpg_document_create :: proc "c" () -> ^Pdf_Document {
	context = runtime.default_context()
	return core_document_create()
}

@(export)
wpg_document_write_to_file :: proc "c" (doc: ^Pdf_Document, filename: cstring) -> c.bool {
	context = runtime.default_context()
	return core_document_write_to_file(doc, filename)
}

@(export)
wpg_document_close :: proc "c" (doc: ^Pdf_Document) {
	context = runtime.default_context()
	core_document_close(doc)
}

@(export)
wpg_document_add_page :: proc "c" (doc: ^Pdf_Document, width, height: c.float) -> ^Pdf_Page {
	context = runtime.default_context()
	return core_document_add_page(doc, f32(width), f32(height))
}

wpg_metadata :: struct {
	title, author, subject, keywords, creator, producer: cstring,
	creation_date, mod_date: cstring,
}

@(export)
wpg_document_set_metadata :: proc "c" (doc: ^Pdf_Document, metadata_struct: ^wpg_metadata) {
	context = runtime.default_context()
	core_document_set_metadata(
		doc,
		metadata_struct.title,
		metadata_struct.author,
		metadata_struct.subject,
		metadata_struct.keywords,
		metadata_struct.creator,
		metadata_struct.producer,
		metadata_struct.creation_date,
		metadata_struct.mod_date,
	)
}

wpg_embedded_font :: struct {
	path, alias: cstring,
}

@(export)
wpg_document_add_embedded_font :: proc "c" (doc: ^Pdf_Document, embedded_font: ^wpg_embedded_font) -> c.bool {
	context = runtime.default_context()
	return core_document_add_embedded_font(doc, embedded_font.path, embedded_font.alias)
}

@(export)
wpg_page_add_text :: proc "c" (page: ^Pdf_Page, text: cstring, x, y: c.float, font_name: cstring, font_size: c.float, text_color_rgb: [3]c.float) {
	context = runtime.default_context()
	core_page_add_text(page, text, f32(x), f32(y), font_name, f32(font_size), text_color_rgb)
}

@(export)
wpg_page_add_image :: proc "c" (page: ^Pdf_Page, path: cstring, x, y, w, h: c.float) {
	context = runtime.default_context()
	core_page_add_image(page, path, f32(x), f32(y), f32(w), f32(h))
}

// ── API de Firma Digital ──────────────────────────────────────

wpg_sig_field :: struct {
	page: c.int,
	rect_llx, rect_lly, rect_urx, rect_ury: c.float,
	reason, location, contact: cstring,
	reserved_size: c.int,
}

@(export)
wpg_document_add_sig_field :: proc "c" (doc: ^Pdf_Document, field: ^wpg_sig_field) -> c.bool {
	context = runtime.default_context()
	if doc == nil || field == nil do return false
	return c.bool(core_document_add_sig_field(doc, field))
}

// Aplica ByteRange y firma DER al buffer del PDF ya serializado en memoria.
// Llamar con signature_data = nil primero para solo parchear ByteRange,
// luego con la firma DER real.
@(export)
wpg_document_patch_signature :: proc "c" (pdf_buf: [^]byte, pdf_len: c.int, ph: ^Sig_Placeholder, signature_data: [^]byte, sig_len: c.int,) -> c.bool {
	context = runtime.default_context()
	if pdf_buf == nil || ph == nil { return false }

	buf : []byte = pdf_buf[:pdf_len]
	sig_slice: []byte
	if signature_data != nil && sig_len > 0 {
		sig_slice = signature_data[:sig_len]
	}
	return c.bool(patch_signature(buf, ph^, sig_slice))
}

// ── Seguridad AES-256 ─────────────────────────────────────────

wpg_security :: struct {
	user_password, owner_password: cstring,
	allow_print, allow_modify, allow_copy, allow_annotate, encrypt_metadata: c.bool,
}

@(export)
wpg_document_set_security :: proc "c" (doc: ^Pdf_Document, sec: ^wpg_security) -> c.bool {
	context = runtime.default_context()
	if doc == nil || sec == nil do return false

	perms: Permissions
	if bool(sec.allow_print) { perms += {.Print, .Print_High} }
	if bool(sec.allow_modify) { perms += {.Modify, .Assemble} }
	if bool(sec.allow_copy) { perms += {.Copy, .Extract} }
	if bool(sec.allow_annotate) { perms += {.Annotate, .Fill_Forms} }

	doc.security = Security_Handler{
		user_password = string(sec.user_password),
		owner_password = string(sec.owner_password),
		permissions = perms,
		encrypt_metadata = bool(sec.encrypt_metadata),
	}
	return true
}
