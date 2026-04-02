package winpdfgenerator

import "core:c"
import "base:runtime"

@export
pdf_document_create :: proc "c" () -> ^Pdf_Document {
	context = runtime.default_context()
	return core_document_create()
}

@export
pdf_document_write_to_file :: proc "c" (doc: ^Pdf_Document, filename: cstring) -> c.bool {
	context = runtime.default_context()
	return core_document_write_to_file(doc, filename)
}

@export
pdf_document_close :: proc "c" (doc: ^Pdf_Document) {
	context = runtime.default_context()
	core_document_close(doc)
}

@export
pdf_document_add_page :: proc "c" (doc: ^Pdf_Document, width, height: c.float) -> ^Pdf_Page {
	context = runtime.default_context()
	return core_document_add_page(doc, f32(width), f32(height))
}

@export
pdf_document_add_embedded_font :: proc "c" (doc: ^Pdf_Document, path: cstring, alias: cstring) -> c.bool {
	context = runtime.default_context()
	return core_document_add_embedded_font(doc, path, alias)
}

@export
pdf_page_add_text :: proc "c" (page: ^Pdf_Page, text: cstring, x, y: c.float, font_name: cstring, size: c.float) {
	context = runtime.default_context()
	core_page_add_text(page, text, f32(x), f32(y), font_name, f32(size))
}

@export
pdf_page_add_image :: proc "c" (page: ^Pdf_Page, path: cstring, x, y, w, h: c.float) {
	context = runtime.default_context()
	core_page_add_image(page, path, f32(x), f32(y), f32(w), f32(h))
}
