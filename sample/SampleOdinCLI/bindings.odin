package main

import "core:c"

// Declaración de tipos opacos (handles).
// Se definen como estructuras vacías ya que se manejan a través de punteros.
Pdf_Document :: struct {}
Pdf_Page :: struct {}
Page_Info :: struct {}
Page_Info_Builder :: struct {}
Pdf_Page_Text_Object :: struct {}
Pdf_Page_Path_Object :: struct {}
Pdf_Page_Image_Object :: struct {}
Annotation :: struct {}
Pdf_Page_Link_Content :: struct {}

// Importación de la biblioteca externa.
// NOTA: Reemplaza "winpdfgenerator.lib" con el nombre real de tu archivo de biblioteca compilado.
foreign import pdfgen "../../bin/WinPdfGenerator.lib"

// Bloque foreign que agrupa las funciones de la API en C.
// Se usa la convención de llamada "c" (cdecl) por defecto [3, 4].
@(default_calling_convention = "c")
foreign pdfgen {
	// Ciclo de vida y utilidades básicas
	pdf_init :: proc() ---
	pdf_shutdown :: proc() ---
	pdf_get_version :: proc() -> c.int ---

	// Documento
	pdf_document_create :: proc() -> ^Pdf_Document ---
	pdf_document_write_to_file :: proc(doc: ^Pdf_Document, filename: cstring) -> c.bool ---
	pdf_document_close :: proc(doc: ^Pdf_Document) ---

	// Configuración de página (PageInfo)
	page_info_builder_create :: proc(page_num, width_pts, height_pts: c.int) -> ^Page_Info_Builder ---
	page_info_builder_set_content_rect :: proc(b: ^Page_Info_Builder, left, top, right, bottom: c.float) ---
	page_info_builder_build :: proc(b: ^Page_Info_Builder) -> ^Page_Info ---
	page_info_free :: proc(info: ^Page_Info) ---

	// Manejo de páginas dentro del documento
	pdf_document_start_page :: proc(doc: ^Pdf_Document, info: ^Page_Info) -> ^Pdf_Page ---
	pdf_document_finish_page :: proc(doc: ^Pdf_Document, page: ^Pdf_Page) ---

	// Objetos de Texto
	pdf_page_text_object_create :: proc(text: cstring, x, y: c.float, font_name: cstring, font_size: c.float) -> ^Pdf_Page_Text_Object ---
	pdf_page_text_object_set_color :: proc(obj: ^Pdf_Page_Text_Object, r, g, b: c.float) ---
	pdf_page_add_text_object :: proc(page: ^Pdf_Page, obj: ^Pdf_Page_Text_Object) ---
	pdf_page_text_object_free :: proc(obj: ^Pdf_Page_Text_Object) ---

	// Objetos de Trazado (Path)
	pdf_page_path_object_create :: proc() -> ^Pdf_Page_Path_Object ---
	pdf_page_path_object_move_to :: proc(obj: ^Pdf_Page_Path_Object, x, y: c.float) ---
	pdf_page_path_object_line_to :: proc(obj: ^Pdf_Page_Path_Object, x, y: c.float) ---
	pdf_page_path_object_curve_to :: proc(obj: ^Pdf_Page_Path_Object, cx1, cy1, cx2, cy2, ex, ey: c.float) ---
	pdf_page_path_object_close :: proc(obj: ^Pdf_Page_Path_Object) ---
	pdf_page_path_object_set_stroke_color :: proc(obj: ^Pdf_Page_Path_Object, r, g, b: c.float) ---
	pdf_page_path_object_set_fill_color :: proc(obj: ^Pdf_Page_Path_Object, r, g, b: c.float) ---
	pdf_page_path_object_set_line_width :: proc(obj: ^Pdf_Page_Path_Object, w: c.float) ---
	pdf_page_add_path_object :: proc(page: ^Pdf_Page, obj: ^Pdf_Page_Path_Object) ---
	pdf_page_path_object_free :: proc(obj: ^Pdf_Page_Path_Object) ---

	// Objetos de Imagen
	pdf_page_image_object_create :: proc(image_path: cstring, x, y, width, height: c.float) -> ^Pdf_Page_Image_Object ---
	pdf_page_add_image_object :: proc(page: ^Pdf_Page, obj: ^Pdf_Page_Image_Object) ---
	pdf_page_image_object_free :: proc(obj: ^Pdf_Page_Image_Object) ---

	// Anotaciones (Highlights)
	highlight_annotation_create :: proc(r, g, b: c.float) -> ^Annotation ---
	highlight_annotation_add_rect :: proc(ann: ^Annotation, left, top, right, bottom: c.float) ---
	highlight_annotation_set_author :: proc(ann: ^Annotation, author: cstring) ---
	pdf_page_add_annotation :: proc(page: ^Pdf_Page, ann: ^Annotation) ---
	annotation_free :: proc(ann: ^Annotation) ---

	// Enlaces (Links)
	pdf_page_link_content_create :: proc(left, top, right, bottom: c.float, uri: cstring) -> ^Pdf_Page_Link_Content ---
	pdf_page_add_link :: proc(page: ^Pdf_Page, link: ^Pdf_Page_Link_Content) ---
	pdf_page_link_content_free :: proc(link: ^Pdf_Page_Link_Content) ---
}
