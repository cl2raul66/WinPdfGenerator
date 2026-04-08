package main

import "core:c"
import "core:fmt"

main :: proc() {
	doc := wpg_document_create()

	page := wpg_document_add_page(doc, 595.0, 842.0)

	// metadata := wpg_metadata{
	// 	title = "Sample PDF Document",
	// 	author = "WinPdfGenerator",
	// 	subject = "PDF Generation Example",
	// 	keywords = "pdf, odin, example",
	// 	creator = "",
	// 	producer = "",
	// }
	// wpg_document_set_metadata(doc, &metadata)

	// font := wpg_embedded_font{
	// 	path = "media\\Inkfree.ttf",
	// 	alias = "InkFree",
	// }
	// wpg_document_add_embedded_font(doc, &font)

	wpg_page_add_text(page, "Hello, PDF 2.0!", 72.0, 750.0, "Helvetica", 24.0, {1, 0, 0})
	// wpg_page_add_text(page, "New text with system font", 72.0, 734.0, "Comic Sans MS", 16.0, {0, 0, 0})
	// wpg_page_add_text(page, "New text with embedded font", 72.0, 718.0, "InkFree", 12.0, {0, 0, 0})

	// local_img : cstring = "media\\logo.png"
	// wpg_page_add_image(page, local_img, 72.0, 568.0, 150.0, 150.0)

	// wpg_page_add_text(page, "Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.\n\nLorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. In id cursus mi pretium tellus duis convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.", 72.0, 412.0, "Times New Roman", 12.0, {0, 0, 0})

	// sig_field := wpg_sig_field{
	// 	page = 0,
	// 	rect_llx = 72.0,
	// 	rect_lly = 72.0,
	// 	rect_urx = 250.0,
	// 	rect_ury = 120.0,
	// 	reason = "Document approval",
	// 	location = "Guatemala",
	// 	contact = "www.linkedin.com/in/cl2raul66",
	// 	reserved_size = 8192,
	// }
	// wpg_document_add_sig_field(doc, &sig_field)

	// security := wpg_security{
	// 	user_password = "user123",
	// 	owner_password = "asd123",
	// 	allow_print = true,
	// 	allow_modify = false,
	// 	allow_copy = false,
	// 	allow_annotate = false,
	// 	encrypt_metadata = true,
	// }
	// wpg_document_set_security(doc, &security)

	result := wpg_document_write_to_file(doc, "hello.pdf")

	wpg_document_close(doc)
	fmt.println("Done")
}
