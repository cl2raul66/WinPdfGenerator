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

wpg_metadata :: struct{
	title, author, subject, keywords, creator, producer: cstring
}

@(export)
wpg_document_set_metadata :: proc "c" (doc: ^Pdf_Document, metadata_struct: ^wpg_metadata) {
	context = runtime.default_context()
	if metadata_struct.creator == "" do metadata_struct.creator = "WinPdfGenerator by R and A Media Lab"
	if metadata_struct.producer == "" do metadata_struct.producer = "WinPdfGenerator by R and A Media Lab"
	core_document_set_metadata(doc, metadata_struct.title, metadata_struct.author, metadata_struct.subject, metadata_struct.keywords, metadata_struct.creator, metadata_struct.producer)
}

wpg_embedded_font :: struct{
	path, alias: cstring
}

@(export)
wpg_document_add_embedded_font :: proc "c" (doc: ^Pdf_Document, embedded_font: ^wpg_embedded_font) -> c.bool {
	context = runtime.default_context()
	return core_document_add_embedded_font(doc, embedded_font.path, embedded_font.alias)
}

@(export)
wpg_page_add_text :: proc "c" (page: ^Pdf_Page, text: cstring, x, y: c.float, font_name: cstring, font_size: c.float, text_color_rgb: [3] c.float) {
	context = runtime.default_context()
	core_page_add_text(page, text, f32(x), f32(y), font_name, f32(font_size), text_color_rgb)
}

@(export)
wpg_page_add_image :: proc "c" (page: ^Pdf_Page, path: cstring, x, y, w, h: c.float) {
	context = runtime.default_context()
	core_page_add_image(page, path, f32(x), f32(y), f32(w), f32(h))
}
