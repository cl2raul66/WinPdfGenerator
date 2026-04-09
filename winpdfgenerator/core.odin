#+private
package winpdfgenerator

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"

WINANSI_TO_UNICODE := [128]rune {
	0x20AC,	0x0000,	0x201A,	0x0192,	0x201E,	0x2026,	0x2020,	0x2021,	0x02C6,	0x2030,	0x0160,	0x2039,	0x0152,	0x0000,	0x017D,	0x0000,	0x0000,	0x2018,	0x2019,	0x201C,	0x201D,	0x2022,	0x2013,	0x2014,	0x02DC,	0x2122,	0x0161,	0x203A,	0x0153,	0x0000,	0x017E,	0x0178,	0x00A0,	0x00A1,	0x00A2,	0x00A3,	0x00A4,	0x00A5,	0x00A6,	0x00A7,	0x00A8,	0x00A9,	0x00AA,	0x00AB,	0x00AC,	0x00AD,	0x00AE,	0x00AF,	0x00B0,	0x00B1,	0x00B2,	0x00B3,	0x00B4,	0x00B5,	0x00B6,	0x00B7,	0x00B8,	0x00B9,	0x00BA,	0x00BB,	0x00BC,	0x00BD,	0x00BE,	0x00BF,	0x00C0,	0x00C1,	0x00C2,	0x00C3,	0x00C4,	0x00C5,	0x00C6,	0x00C7,	0x00C8,	0x00C9,	0x00CA,	0x00CB,	0x00CC,	0x00CD,	0x00CE,	0x00CF,	0x00D0,	0x00D1,	0x00D2,	0x00D3,	0x00D4,	0x00D5,	0x00D6,	0x00D7,	0x00D8, 0x00D9,	0x00DA,	0x00DB,	0x00DC,	0x00DD,	0x00DE,	0x00DF,	0x00E0,	0x00E1,	0x00E2,	0x00E3,	0x00E4,	0x00E5,	0x00E6,	0x00E7,	0x00E8,	0x00E9,	0x00EA,	0x00EB,	0x00EC,	0x00ED,	0x00EE,	0x00EF,	0x00F0,	0x00F1,	0x00F2,	0x00F3,	0x00F4,	0x00F5,	0x00F6,	0x00F7,	0x00F8,	0x00F9,	0x00FA,	0x00FB,	0x00FC,	0x00FD,	0x00FE,	0x00FF,
}

core_document_create :: proc() -> ^Pdf_Document {
	doc := new(Pdf_Document)
	doc.pages = make([dynamic]^Pdf_Page)
	doc.sig_fields = make([dynamic]^Sig_Field)
	doc.embedded_fonts = make(map[string]Embedded_Font)
	doc.file_id[0] = generate_file_id("seed_1")
	doc.file_id[1] = generate_file_id("seed_2")
	return doc
}

core_document_write_to_file :: proc(doc: ^Pdf_Document, filename: cstring) -> c.bool {
	if doc == nil || filename == nil do return false
	return c.bool(serialize_document(doc, string(filename)))
}

core_document_close :: proc(doc: ^Pdf_Document) {
	if doc == nil do return
	for page in doc.pages {
		for item in page.items {
			#partial switch v in item.data {
			case Pdf_Page_Text_Object:
				delete(v.text)
				delete(v.font_name)
			case Pdf_Page_Image_Object:
				delete(v.image_path)
			}
		}
		delete(page.items)
		delete(page.annotations)
		free(page)
	}
	delete(doc.pages)
	for _, emb in doc.embedded_fonts { delete(emb.ttf_data) }
	delete(doc.embedded_fonts)
	for sf in doc.sig_fields { free(sf) }
	delete(doc.sig_fields)
	free(doc)
}

core_document_add_page :: proc(doc: ^Pdf_Document, width, height: f32) -> ^Pdf_Page {
	page := new(Pdf_Page)
	page.media_box = Rect{0, 0, width, height}
	page.items = make([dynamic]Content_Item)
	page.annotations = make([dynamic]Annotation)
	append(&doc.pages, page)
	return page
}

core_document_add_embedded_font :: proc(doc: ^Pdf_Document, path: cstring, alias: cstring) -> bool {
	if doc == nil || path == nil || alias == nil do return false
	alias_str := string(alias)
	if alias_str in doc.embedded_fonts do return true

	ttf_data, _ := os.read_entire_file(string(path), context.allocator)
	if len(ttf_data) == 0 {
		fmt.printf("[WinPdfGenerator] ERROR: No se pudo cargar la fuente: %s\n", string(path))
		return false
	}

	info: stbtt.fontinfo
	if !stbtt.InitFont(&info, raw_data(ttf_data), 0) {
		delete(ttf_data)
		return false
	}

	ascent, descent, line_gap: c.int
	stbtt.GetFontVMetrics(&info, &ascent, &descent, &line_gap)

	x0, y0, x1, y1: c.int
	stbtt.GetFontBoundingBox(&info, &x0, &y0, &x1, &y1)

	scale := stbtt.ScaleForMappingEmToPixels(&info, 1000.0)

	emb: Embedded_Font
	emb.alias = strings.clone(alias_str)
	emb.ttf_data = ttf_data
	emb.ascent = f32(ascent) * scale
	emb.descent = f32(descent) * scale
	emb.bbox = Rect{f32(x0) * scale, f32(y0) * scale, f32(x1) * scale, f32(y1) * scale}
	emb.cap_height = emb.ascent
	emb.stem_v = 80.0
	emb.italic_angle = 0.0
	emb.flags = 32

	for i in 32 ..= 255 {
		codepoint := rune(i)
		if i >= 128 { codepoint = WINANSI_TO_UNICODE[i - 128] }
		advance, lsb: c.int
		stbtt.GetCodepointHMetrics(&info, codepoint, &advance, &lsb)
		emb.widths[i] = f32(advance) * scale
	}

	doc.embedded_fonts[emb.alias] = emb
	return true
}

core_page_add_text :: proc(page: ^Pdf_Page, text: cstring, x, y: f32, font_name: cstring, font_size: f32, text_color_rgb: [3]f32) {
	if page == nil do return
	append(&page.items, Content_Item{data = Pdf_Page_Text_Object{
		text = strings.clone_from_cstring(text),
		x = x,
		y = y,
		font_name = strings.clone_from_cstring(font_name),
		font_size = font_size,
		color = Color_RGB{text_color_rgb[0], text_color_rgb[1], text_color_rgb[2]},
	}})
}

core_page_add_image :: proc(page: ^Pdf_Page, path: cstring, x, y, width, height: f32) {
	if page == nil do return
	append(&page.items, Content_Item{data = Pdf_Page_Image_Object{
		image_path = strings.clone_from_cstring(path),
		x = x,
		y = y,
		width = width,
		height = height,
	}})
}

core_document_set_metadata :: proc(doc: ^Pdf_Document, title, author, subject, keywords, creator, producer, creation_date, mod_date: cstring) {
	if doc == nil do return
	if doc.metadata_info.title != "" do delete(doc.metadata_info.title)
	if doc.metadata_info.author != "" do delete(doc.metadata_info.author)
	if doc.metadata_info.subject != "" do delete(doc.metadata_info.subject)
	if doc.metadata_info.keywords != "" do delete(doc.metadata_info.keywords)
	if doc.metadata_info.creator != "" do delete(doc.metadata_info.creator)
	if doc.metadata_info.producer != "" do delete(doc.metadata_info.producer)
	if doc.metadata_info.creation_date != "" do delete(doc.metadata_info.creation_date)
	if doc.metadata_info.mod_date != "" do delete(doc.metadata_info.mod_date)
	if title != nil do doc.metadata_info.title = strings.clone_from_cstring(title)
	if author != nil do doc.metadata_info.author = strings.clone_from_cstring(author)
	if subject != nil do doc.metadata_info.subject = strings.clone_from_cstring(subject)
	if keywords != nil do doc.metadata_info.keywords = strings.clone_from_cstring(keywords)
	if creator != nil do doc.metadata_info.creator = strings.clone_from_cstring(creator)
	if producer != nil do doc.metadata_info.producer = strings.clone_from_cstring(producer)
	if creation_date != nil && len(string(creation_date)) > 0 {
		doc.metadata_info.creation_date = strings.clone_from_cstring(creation_date)
	}
	if mod_date != nil && len(string(mod_date)) > 0 {
		doc.metadata_info.mod_date = strings.clone_from_cstring(mod_date)
	}
}

core_document_add_sig_field :: proc(doc: ^Pdf_Document, field: ^wpg_sig_field_dto) -> bool {
	if doc == nil || field == nil do return false

	sf := new(Sig_Field)
	sf.page = int(field.page)
	sf.rect = Rect{
		f32(field.rect_llx), f32(field.rect_lly),
		f32(field.rect_urx), f32(field.rect_ury),
	}
	sf.sub_filter = .PKCS7_Detached
	sf.reason = field.reason != nil ? string(field.reason) : ""
	sf.location = field.location != nil ? string(field.location) : ""
	sf.contact = field.contact != nil ? string(field.contact) : ""
	sf.reserved_size = int(field.reserved_size)
	append(&doc.sig_fields, sf)
	return true
}

// ── Tipos de recursos de página ───────────────────────────────

Image_Resource :: struct {
	alias: string,
	obj_id, smask_id, width, height, channels: int,
	rgb_data, alpha_data: []byte,
}

Page_Resources :: struct {
	font_map: map[string]string,
	images:   [dynamic]Image_Resource,
}

// ── Métricas de fuentes de sistema ───────────────────────────

System_Font_Metrics :: struct {
	bbox: [4]int,
	ascent,	descent, cap_height, stem_v, flags, italic_angle: int,
}

HELVETICA_WIDTHS :: [224]int{
	278, 278, 355, 556, 556, 889, 667, 222, 333, 333, 389, 584, 278, 333, 278, 278,	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,	1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, 	222, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,	556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584, 278,	556, 278, 222, 556, 333, 1000, 556, 556, 278, 1000, 667, 333, 1000, 278, 500, 667, 278, 278, 222, 222, 333, 333, 350, 556, 1000, 222, 1000, 500, 333, 944, 278, 500,	278, 333, 556, 556, 556, 556, 260, 556, 333, 737, 370, 556, 584, 333, 737, 333,	400, 584, 333, 333, 333, 556, 537, 278, 333, 333, 365, 556, 834, 834, 834, 611,	667, 667, 667, 667, 667, 667, 1000, 722, 667, 667, 667, 667, 278, 278, 278, 278, 722, 722, 778, 778, 778, 778, 778, 584, 778, 722, 722, 722, 722, 667, 667, 611, 	556, 556, 556, 556, 556, 556, 889, 500, 556, 556, 556, 556, 278, 278, 278, 278,	556, 556, 556, 556, 556, 556, 556, 584, 611, 556, 556,556, 556, 500, 556, 500,
}

get_type1_metrics :: proc(font_name: string) -> System_Font_Metrics {
	switch font_name {
	case "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique":
		return {bbox = {-166, -225, 1000, 931}, ascent = 718,  descent = -207, cap_height = 718, stem_v = 88,  flags = 32, italic_angle = 0}
	case "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic":
		return {bbox = {-168, -218, 1000, 898}, ascent = 683,  descent = -217, cap_height = 662, stem_v = 84,  flags = 34, italic_angle = 0}
	case "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique":
		return {bbox = {-23,  -250,  715,  805}, ascent = 629, descent = -157, cap_height = 562, stem_v = 51,  flags = 33, italic_angle = 0}
	case:
		return {bbox = {-100, -200, 1000, 900}, ascent = 800,  descent = -200, cap_height = 700, stem_v = 80,  flags = 32, italic_angle = 0}
	}
}

write_font_widths :: proc(sb: ^strings.Builder, font_name: string) {
	strings.write_string(sb, "[")
	switch font_name {
	case "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique":
		for w in HELVETICA_WIDTHS { fmt.sbprintf(sb, "%d ", w) }
	case:
		for _ in 0 ..< 224 { strings.write_string(sb, "600 ") }
	}
	strings.write_string(sb, "]")
}

@(private)
is_standard_type1 :: proc(font_name: string) -> bool {
	switch font_name {
	case "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique",
	     "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic",
	     "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique",
	     "Symbol", "ZapfDingbats":
		return true
	}
	return false
}

@(private)
serialize_sys_font_dict :: proc(font_name: string) -> string {
	ps_name, _ := strings.replace_all(font_name, " ", "")
	defer delete(ps_name)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	if is_standard_type1(font_name) {
		m := get_type1_metrics(font_name)
		fmt.sbprintf(&sb,
			"<< /Type /Font /Subtype /Type1 /BaseFont /%s /Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 255 /Widths ",
			ps_name)
		write_font_widths(&sb, font_name)
		fmt.sbprintf(&sb,
			" /FontDescriptor << /Type /FontDescriptor /FontName /%s /Flags %d /FontBBox [%d %d %d %d] /ItalicAngle %d /Ascent %d /Descent %d /CapHeight %d /StemV %d >> >>",
			ps_name, m.flags, m.bbox[0], m.bbox[1], m.bbox[2], m.bbox[3],
			m.italic_angle, m.ascent, m.descent, m.cap_height, m.stem_v)
	} else {
		fmt.sbprintf(&sb,
			"<< /Type /Font /Subtype /TrueType /BaseFont /%s /Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 255 /Widths ",
			ps_name)
		write_font_widths(&sb, "")
		fmt.sbprintf(&sb,
			" /FontDescriptor << /Type /FontDescriptor /FontName /%s /Flags 32 /FontBBox [-100 -200 1000 900] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 800 /StemV 80 >> >>",
			ps_name)
	}

	return strings.clone(strings.to_string(sb))
}

// ── Tipos del pipeline ────────────────────────────────────────

Object_Role :: enum {
	Catalog,
	Pages_Tree,
	Page,
	Content_Stream,
	Image_Smask,
	Image_XObject,
	Font_File,
	Font_Widths,
	Font_Descriptor,
	Font_Dict,
	Metadata,
	Encrypt_Dict,
	Sig_Value,
	Sig_Widget,
	Sig_Appearance,
	Sig_AcroForm,
	ObjStm,
}

Obj_Descriptor :: struct {
	id: int,
	role: Object_Role,
	in_objstm: bool,
	objstm_idx: int,
}

Embedded_Font_Ids :: struct {
	file_id, widths_id,	desc_id, font_id: int,
}

Sig_Field_Ids :: struct {
	sig_value_id, widget_id, ap_id: int,
	placeholder:  Sig_Placeholder,
}

Page_Data :: struct {
	resources:   Page_Resources,
	content_str: string,
}

Render_Plan :: struct {
	catalog_id,	pages_id, metadata_id, encrypt_id, acroform_id, xref_stream_id, total_ids: int,
	page_ids, content_ids, objstm_ids: []int,
	sig_ids: []Sig_Field_Ids,
	page_data: []Page_Data,
	emb_ids: map[string]Embedded_Font_Ids,
	sys_font_ids: map[string]int,
	objects: [dynamic]Obj_Descriptor,
}

render_plan_destroy :: proc(plan: ^Render_Plan) {
	delete(plan.page_ids)
	delete(plan.content_ids)
	delete(plan.objstm_ids)
	delete(plan.sig_ids)
	for pd in plan.page_data {
		delete(pd.content_str)
		for _, alias in pd.resources.font_map { delete(alias) }
		delete(pd.resources.font_map)
		for img in pd.resources.images {
			delete(img.alias)
			delete(img.rgb_data)
			if img.alpha_data != nil { delete(img.alpha_data) }
		}
		delete(pd.resources.images)
	}
	delete(plan.page_data)
	delete(plan.emb_ids)
	delete(plan.sys_font_ids)
	delete(plan.objects)
}

// ── Predicado ObjStm ─────────────────────────────────────────

@(private)
is_objstm_eligible :: proc(role: Object_Role) -> bool {
	#partial switch role {
	case .Catalog, .Pages_Tree, .Page, .Font_Widths, .Font_Descriptor, .Font_Dict:
		return true
	}
	return false
}

// ── Etapa 1: Collect ──────────────────────────────────────────

pipeline_collect :: proc(doc: ^Pdf_Document) -> (page_data: []Page_Data, ok: bool) {
	n := len(doc.pages)
	page_data = make([]Page_Data, n)

	for page, i in doc.pages {
		pr := &page_data[i].resources
		pr.font_map = make(map[string]string)
		pr.images = make([dynamic]Image_Resource)

		font_alias_num := 1
		for item in page.items {
			#partial switch v in item.data {
			case Pdf_Page_Text_Object:
				if !(v.font_name in pr.font_map) {
					pr.font_map[v.font_name] = fmt.aprintf("F%d", font_alias_num)
					font_alias_num += 1
				}
			case Pdf_Page_Image_Object:
				c_path, _ := strings.clone_to_cstring(v.image_path)
				defer delete(c_path)

				w, h, channels: c.int
				img_data := stbi.load(c_path, &w, &h, &channels, 0)
				if img_data == nil {
					fmt.printf("[WinPdfGenerator] ERROR: No se pudo cargar la imagen: %s\n", v.image_path)
					continue
				}
				defer stbi.image_free(img_data)

				img_res: Image_Resource
				img_res.alias = fmt.aprintf("Im%d", len(pr.images) + 1)
				img_res.width = int(w)
				img_res.height = int(h)
				img_res.channels = int(channels)

				pixels := img_res.width * img_res.height
				src := ([^]byte)(img_data)[:pixels * int(channels)]

				if channels == 1 || channels == 3 {
					img_res.rgb_data = make([]byte, pixels * int(channels))
					copy(img_res.rgb_data, src)
				} else if channels == 2 || channels == 4 {
					color_ch := int(channels) - 1
					img_res.rgb_data = make([]byte, pixels * color_ch)
					img_res.alpha_data = make([]byte, pixels)
					for p in 0 ..< pixels {
						for c_idx in 0 ..< color_ch {
							img_res.rgb_data[p * color_ch + c_idx] = src[p * int(channels) + c_idx]
						}
						img_res.alpha_data[p] = src[p * int(channels) + color_ch]
					}
				}
				append(&pr.images, img_res)
			}
		}

		csb := strings.builder_make()
		img_idx := 0
		for item in page.items {
			switch v in item.data {
			case Pdf_Page_Text_Object:
				alias := pr.font_map[v.font_name]
				alias_name := fmt.aprintf("/%s", alias)
				write_text_begin(&csb)
				write_fill_rgb(&csb, v.color)
				write_text_font(&csb, Pdf_Name(alias_name), v.font_size)
				write_text_matrix(&csb, 1, 0, 0, 1, v.x, v.y)
				write_text_show(&csb, v.text)
				write_text_end(&csb)
				delete(alias_name)
			case Pdf_Page_Path_Object:
				vv := v
				write_path_object(&csb, &vv)
			case Pdf_Page_Image_Object:
				if img_idx < len(pr.images) {
					img_res := pr.images[img_idx]; img_idx += 1
					alias_name := fmt.aprintf("/%s", img_res.alias)
					write_image_do(&csb, Pdf_Name(alias_name), v.x, v.y, v.width, v.height)
					delete(alias_name)
				}
			}
		}
		page_data[i].content_str = strings.clone(strings.to_string(csb))
		strings.builder_destroy(&csb)
	}

	return page_data, true
}

// ── Etapa 2: Classify ─────────────────────────────────────────

pipeline_classify :: proc(plan: ^Render_Plan, next_id: ^int) {
	eligible_count := 0
	for &obj in plan.objects {
		obj.in_objstm = false;
		obj.objstm_idx = -1
		if is_objstm_eligible(obj.role) {
			obj.in_objstm  = true
			obj.objstm_idx = eligible_count / MAX_OBJECTS_PER_OBJSTM
			eligible_count += 1
		}
	}

	num_objstm := 0
	if eligible_count > 0 {
		num_objstm = (eligible_count + MAX_OBJECTS_PER_OBJSTM - 1) / MAX_OBJECTS_PER_OBJSTM
	}

	delete(plan.objstm_ids)
	plan.objstm_ids = make([]int, num_objstm)
	for i in 0 ..< num_objstm {
		plan.objstm_ids[i] = next_id^
		append(&plan.objects, Obj_Descriptor{
			id = next_id^,
			role = .ObjStm,
			in_objstm  = false,
			objstm_idx = -1,
		})
		next_id^ += 1
	}
}

// ── Etapa 3: Assign ───────────────────────────────────────────

pipeline_assign :: proc(doc: ^Pdf_Document, page_data: []Page_Data) -> (plan: Render_Plan, next_id: int) {
	n := len(doc.pages)
	ns := len(doc.sig_fields)
	next_id = 1

	plan.page_ids = make([]int, n)
	plan.content_ids = make([]int, n)
	plan.objstm_ids = make([]int, 0)
	plan.page_data = page_data
	plan.sys_font_ids = make(map[string]int)
	plan.emb_ids = make(map[string]Embedded_Font_Ids)
	plan.objects = make([dynamic]Obj_Descriptor)

	// Catálogo
	plan.catalog_id = next_id; next_id += 1
	append(&plan.objects, Obj_Descriptor{id = plan.catalog_id, role = .Catalog})

	// Árbol de páginas
	plan.pages_id = next_id; next_id += 1
	append(&plan.objects, Obj_Descriptor{id = plan.pages_id, role = .Pages_Tree})

	// Diccionarios de página
	for i in 0 ..< n {
		plan.page_ids[i] = next_id; next_id += 1
		append(&plan.objects, Obj_Descriptor{id = plan.page_ids[i], role = .Page})
	}

	// Content streams — solo si la página tiene contenido
	for i in 0 ..< n {
		if len(page_data[i].content_str) > 0 {
			plan.content_ids[i] = next_id; next_id += 1
			append(&plan.objects, Obj_Descriptor{id = plan.content_ids[i], role = .Content_Stream})
		}
		// Si content_ids[i] == 0 la página no incluirá /Contents
	}

	// Imágenes
	for i in 0 ..< n {
		for j in 0 ..< len(plan.page_data[i].resources.images) {
			img := &plan.page_data[i].resources.images[j]
			if img.alpha_data != nil {
				img.smask_id = next_id; next_id += 1
				append(&plan.objects, Obj_Descriptor{id = img.smask_id, role = .Image_Smask})
			}
			img.obj_id = next_id; next_id += 1
			append(&plan.objects, Obj_Descriptor{id = img.obj_id, role = .Image_XObject})
		}
	}

	// Fuentes embebidas
	for key in doc.embedded_fonts {
		ids: Embedded_Font_Ids
		ids.file_id = next_id; next_id += 1
		ids.widths_id = next_id; next_id += 1
		ids.desc_id = next_id; next_id += 1
		ids.font_id = next_id; next_id += 1
		plan.emb_ids[key] = ids
		append(&plan.objects, Obj_Descriptor{id = ids.file_id, role = .Font_File})
		append(&plan.objects, Obj_Descriptor{id = ids.widths_id, role = .Font_Widths})
		append(&plan.objects, Obj_Descriptor{id = ids.desc_id, role = .Font_Descriptor})
		append(&plan.objects, Obj_Descriptor{id = ids.font_id, role = .Font_Dict})
	}

	// Fuentes de sistema como objetos indirectos (ISO 32000-2 §4 — "Debe ser Indirecto")
	// Recolectamos nombres únicos de fuentes no embebidas a través de todas las páginas.
	for i in 0 ..< n {
		for fname, _ in page_data[i].resources.font_map {
			if !(fname in doc.embedded_fonts) && !(fname in plan.sys_font_ids) {
				plan.sys_font_ids[fname] = next_id
				append(&plan.objects, Obj_Descriptor{id = next_id, role = .Font_Dict})
				next_id += 1
			}
		}
	}

	// Metadatos XMP — solo si el caller configuró al menos un campo
	if pdf_info_has_data(doc.metadata_info) {
		plan.metadata_id = next_id; next_id += 1
		append(&plan.objects, Obj_Descriptor{id = plan.metadata_id, role = .Metadata})
	}

	// Campos de firma
	plan.sig_ids = make([]Sig_Field_Ids, ns)
	if ns > 0 {
		for i in 0 ..< ns {
			plan.sig_ids[i].sig_value_id = next_id; next_id += 1
			append(&plan.objects, Obj_Descriptor{id = plan.sig_ids[i].sig_value_id, role = .Sig_Value})

			plan.sig_ids[i].widget_id = next_id; next_id += 1
			append(&plan.objects, Obj_Descriptor{id = plan.sig_ids[i].widget_id, role = .Sig_Widget})

			// /AP obligatorio en PDF 2.0 para widgets con Rect de dimensiones > 0
			sf := doc.sig_fields[i]
			w  := sf.rect.urx - sf.rect.llx
			h  := sf.rect.ury - sf.rect.lly
			if w > 0 && h > 0 {
				plan.sig_ids[i].ap_id = next_id; next_id += 1
				append(&plan.objects, Obj_Descriptor{id = plan.sig_ids[i].ap_id, role = .Sig_Appearance})
			}
		}

		plan.acroform_id = next_id; next_id += 1
		append(&plan.objects, Obj_Descriptor{id = plan.acroform_id, role = .Sig_AcroForm})
	}

	plan.encrypt_id = 0
	return
}

// ── Helpers de serialización ──────────────────────────────────

@(private)
build_page_resource_string :: proc(pr: ^Page_Resources, plan: ^Render_Plan) -> string {
	frsb := strings.builder_make()
	defer strings.builder_destroy(&frsb)

	if len(pr.font_map) > 0 {
		strings.write_string(&frsb, "/Font << ")
		for fname, alias in pr.font_map {
			if fname in plan.emb_ids {
				ids := plan.emb_ids[fname]
				fmt.sbprintf(&frsb, "/%s %d 0 R ", alias, ids.font_id)
			} else if fid, ok := plan.sys_font_ids[fname]; ok {
				// Fuente de sistema: objeto indirecto asignado en pipeline_assign
				fmt.sbprintf(&frsb, "/%s %d 0 R ", alias, fid)
			}
		}
		strings.write_string(&frsb, ">> ")
	}

	if len(pr.images) > 0 {
		strings.write_string(&frsb, "/XObject << ")
		for img in pr.images {
			fmt.sbprintf(&frsb, "/%s %d 0 R ", img.alias, img.obj_id)
		}
		strings.write_string(&frsb, ">> ")
	}

	return strings.clone(strings.to_string(frsb))
}

@(private)
serialize_non_stream_value :: proc(obj_id: int, plan: ^Render_Plan, doc: ^Pdf_Document,	page_idx: int, emb_font_key: string,
) -> string {
	tmp := strings.builder_make()
	defer strings.builder_destroy(&tmp)

	switch {
	case obj_id == plan.catalog_id:
		strings.write_string(&tmp, "<< /Type /Catalog")
		fmt.sbprintf(&tmp, " /Pages %d 0 R", plan.pages_id)
		if plan.metadata_id > 0 {
			fmt.sbprintf(&tmp, " /Metadata %d 0 R", plan.metadata_id)
		}
		if plan.acroform_id > 0 {
			fmt.sbprintf(&tmp, " /AcroForm %d 0 R", plan.acroform_id)
		}
		strings.write_string(&tmp, " >>")

	case obj_id == plan.pages_id:
		kids_sb := strings.builder_make()
		defer strings.builder_destroy(&kids_sb)
		for pid in plan.page_ids { fmt.sbprintf(&kids_sb, "%d 0 R ", pid) }
		fmt.sbprintf(&tmp, "<< /Type /Pages /Count %d /Kids [%s] >>",
			len(plan.page_ids), strings.to_string(kids_sb))

	case page_idx >= 0 && page_idx < len(doc.pages):
		page := doc.pages[page_idx]
		pr := &plan.page_data[page_idx].resources
		res := build_page_resource_string(pr, plan)
		defer delete(res)

		strings.write_string(&tmp, "<< /Type /Page")
		fmt.sbprintf(&tmp, " /Parent %d 0 R", plan.pages_id)
		fmt.sbprintf(&tmp, " /MediaBox [%.4f %.4f %.4f %.4f]",
			page.media_box.llx, page.media_box.lly,
			page.media_box.urx, page.media_box.ury)

		// /Contents solo si la página tiene contenido
		cid := plan.content_ids[page_idx]
		if cid != 0 {
			fmt.sbprintf(&tmp, " /Contents %d 0 R", cid)
		}

		fmt.sbprintf(&tmp, " /Resources << %s>>", res)

		// /Annots: widgets de firma en esta página
		annots_sb := strings.builder_make()
		defer strings.builder_destroy(&annots_sb)
		for i in 0 ..< len(doc.sig_fields) {
			sf := doc.sig_fields[i]
			if sf.page == page_idx {
				fmt.sbprintf(&annots_sb, "%d 0 R ", plan.sig_ids[i].widget_id)
			}
		}
		annots_str := strings.to_string(annots_sb)
		if len(annots_str) > 0 {
			fmt.sbprintf(&tmp, " /Annots [%s]", annots_str)
		}

		strings.write_string(&tmp, " >>")

	case obj_id == plan.acroform_id && plan.acroform_id > 0:
		widget_sb := strings.builder_make()
		defer strings.builder_destroy(&widget_sb)
		for sid in plan.sig_ids {
			fmt.sbprintf(&widget_sb, "%d 0 R ", sid.widget_id)
		}
		fmt.sbprintf(&tmp, "<< /Fields [%s] /SigFlags 3 >>", strings.to_string(widget_sb))

	case emb_font_key != "" && obj_id == plan.emb_ids[emb_font_key].widths_id:
		emb := doc.embedded_fonts[emb_font_key]
		strings.write_string(&tmp, "[ ")
		for i in 32 ..= 255 { fmt.sbprintf(&tmp, "%.0f ", emb.widths[i]) }
		strings.write_string(&tmp, "]")

	case emb_font_key != "" && obj_id == plan.emb_ids[emb_font_key].desc_id:
		emb := doc.embedded_fonts[emb_font_key]
		ids := plan.emb_ids[emb_font_key]
		safe_alias, _ := strings.replace_all(emb.alias, " ", "")
		pdf_font_name := fmt.aprintf("AAAAAA+%s", safe_alias)
		defer delete(safe_alias)
		defer delete(pdf_font_name)
		fmt.sbprintf(&tmp,
			"<< /Type /FontDescriptor /FontName /%s /Flags %d /FontBBox [%.0f %.0f %.0f %.0f] /ItalicAngle %.0f /Ascent %.0f /Descent %.0f /CapHeight %.0f /StemV %.0f /FontFile2 %d 0 R >>",
			pdf_font_name, emb.flags,
			emb.bbox.llx, emb.bbox.lly, emb.bbox.urx, emb.bbox.ury,
			emb.italic_angle, emb.ascent, emb.descent, emb.cap_height, emb.stem_v,
			ids.file_id)

	case emb_font_key != "" && obj_id == plan.emb_ids[emb_font_key].font_id:
		emb := doc.embedded_fonts[emb_font_key]
		ids := plan.emb_ids[emb_font_key]
		safe_alias, _ := strings.replace_all(emb.alias, " ", "")
		pdf_font_name := fmt.aprintf("AAAAAA+%s", safe_alias)
		defer delete(safe_alias)
		defer delete(pdf_font_name)
		fmt.sbprintf(&tmp,
			"<< /Type /Font /Subtype /TrueType /BaseFont /%s /FirstChar 32 /LastChar 255 /Widths %d 0 R /FontDescriptor %d 0 R /Encoding /WinAnsiEncoding >>",
			pdf_font_name, ids.widths_id, ids.desc_id)
	}

	return strings.clone(strings.to_string(tmp))
}

@(private)
route_non_stream :: proc(obj_id: int, val: string, desc: Obj_Descriptor, sb: ^strings.Builder, builders: []ObjStm_Builder, records: []Xref_Record,
) {
	if desc.in_objstm && desc.objstm_idx >= 0 {
		objstm_add(&builders[desc.objstm_idx], obj_id, val)
	} else {
		offset := i64(strings.builder_len(sb^))
		fmt.sbprintf(sb, "%d 0 obj\n%s\nendobj\n", obj_id, val)
		records[obj_id] = Xref_Record{.Direct, offset, 0}
	}
}

// ── Etapa 4: Render ───────────────────────────────────────────

pipeline_render :: proc(doc: ^Pdf_Document, plan: ^Render_Plan, enc_ctx: ^Encryption_Context) -> (sb: strings.Builder, records: []Xref_Record) {
	records = make([]Xref_Record, plan.total_ids + 1)
	records[0] = Xref_Record{.Free, 0, 65535}

	sb = strings.builder_make()
	n := len(doc.pages)

	obj_info := make(map[int]Obj_Descriptor)
	defer delete(obj_info)
	for desc in plan.objects { obj_info[desc.id] = desc }

	builders := make([]ObjStm_Builder, len(plan.objstm_ids))
	for i in 0 ..< len(plan.objstm_ids) {
		builders[i] = objstm_make(plan.objstm_ids[i])
	}
	defer {
		for i in 0 ..< len(builders) { objstm_destroy(&builders[i]) }
		delete(builders)
	}

	write_header(&sb)

	// Catálogo
	{
		val := serialize_non_stream_value(plan.catalog_id, plan, doc, -1, "")
		defer delete(val)
		route_non_stream(plan.catalog_id, val, obj_info[plan.catalog_id], &sb, builders, records)
	}

	// Árbol de páginas
	{
		val := serialize_non_stream_value(plan.pages_id, plan, doc, -1, "")
		defer delete(val)
		route_non_stream(plan.pages_id, val, obj_info[plan.pages_id], &sb, builders, records)
	}

	// Diccionarios de página
	for i in 0 ..< n {
		pid := plan.page_ids[i]
		val := serialize_non_stream_value(pid, plan, doc, i, "")
		defer delete(val)
		route_non_stream(pid, val, obj_info[pid], &sb, builders, records)
	}

	// Content streams (solo páginas con contenido)
	for i in 0 ..< n {
		if plan.content_ids[i] == 0 { continue }
		cid := plan.content_ids[i]
		content := plan.page_data[i].content_str
		offset := i64(strings.builder_len(sb))

		if enc_ctx != nil {
			encrypted := encrypt_data(enc_ctx.file_key, transmute([]byte)content)
			defer delete(encrypted)
			fmt.sbprintf(&sb, "%d 0 obj\n<< /Length %d /Filter /Crypt >>\nstream\n", cid, len(encrypted))
			strings.write_bytes(&sb, encrypted)
			strings.write_string(&sb, "\nendstream\nendobj\n")
		} else {
			fmt.sbprintf(&sb, "%d 0 obj\n<< /Length %d >>\nstream\n%sendstream\nendobj\n",
				cid, len(content), content)
		}
		records[cid] = Xref_Record{.Direct, offset, 0}
	}

	// Imágenes
	for i in 0 ..< n {
		pr := &plan.page_data[i].resources
		for img in pr.images {
			if img.smask_id != 0 {
				comp_alpha, _ := filter_apply_flate(img.alpha_data)
				use_alpha_flate := comp_alpha != nil && len(comp_alpha) < len(img.alpha_data)
				alpha_payload := use_alpha_flate ? comp_alpha : img.alpha_data

				offset := i64(strings.builder_len(sb))
				hdr := strings.builder_make()
				fmt.sbprintf(&hdr,
					"%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceGray /BitsPerComponent 8",
					img.smask_id, img.width, img.height)
				if use_alpha_flate { strings.write_string(&hdr, " /Filter /FlateDecode") }
				fmt.sbprintf(&hdr, " /Length %d >>\nstream\n", len(alpha_payload))
				strings.write_string(&sb, strings.to_string(hdr))
				strings.builder_destroy(&hdr)
				strings.write_bytes(&sb, alpha_payload)
				strings.write_string(&sb, "\nendstream\nendobj\n")
				records[img.smask_id] = Xref_Record{.Direct, offset, 0}
				if use_alpha_flate { delete(comp_alpha) }
			}

			comp_rgb, _ := filter_apply_flate(img.rgb_data)
			use_rgb_flate := comp_rgb != nil && len(comp_rgb) < len(img.rgb_data)
			rgb_payload := use_rgb_flate ? comp_rgb : img.rgb_data
			color_space := img.channels == 1 || img.channels == 2 ? "/DeviceGray" : "/DeviceRGB"

			offset := i64(strings.builder_len(sb))
			hdr := strings.builder_make()
			fmt.sbprintf(&hdr,
				"%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent 8",
				img.obj_id, img.width, img.height, color_space)
			if use_rgb_flate { strings.write_string(&hdr, " /Filter /FlateDecode") }
			if img.smask_id != 0 { fmt.sbprintf(&hdr, " /SMask %d 0 R", img.smask_id) }
			fmt.sbprintf(&hdr, " /Length %d >>\nstream\n", len(rgb_payload))
			strings.write_string(&sb, strings.to_string(hdr))
			strings.builder_destroy(&hdr)
			strings.write_bytes(&sb, rgb_payload)
			strings.write_string(&sb, "\nendstream\nendobj\n")
			records[img.obj_id] = Xref_Record{.Direct, offset, 0}
			if use_rgb_flate { delete(comp_rgb) }
		}
	}

	// Fuentes embebidas
	for key, emb in doc.embedded_fonts {
		ids := plan.emb_ids[key]

		offset_file := i64(strings.builder_len(sb))
		fmt.sbprintf(&sb, "%d 0 obj\n<< /Length %d /Length1 %d >>\nstream\n", ids.file_id, len(emb.ttf_data), len(emb.ttf_data))
		strings.write_bytes(&sb, emb.ttf_data)
		strings.write_string(&sb, "\nendstream\nendobj\n")
		records[ids.file_id] = Xref_Record{.Direct, offset_file, 0}

		{
			val := serialize_non_stream_value(ids.widths_id, plan, doc, -1, key)
			defer delete(val)
			route_non_stream(ids.widths_id, val, obj_info[ids.widths_id], &sb, builders, records)
		}
		{
			val := serialize_non_stream_value(ids.desc_id, plan, doc, -1, key)
			defer delete(val)
			route_non_stream(ids.desc_id, val, obj_info[ids.desc_id], &sb, builders, records)
		}
		{
			val := serialize_non_stream_value(ids.font_id, plan, doc, -1, key)
			defer delete(val)
			route_non_stream(ids.font_id, val, obj_info[ids.font_id], &sb, builders, records)
		}
	}

	// Fuentes de sistema como objetos indirectos
	for fname, fid in plan.sys_font_ids {
		val := serialize_sys_font_dict(fname)
		route_non_stream(fid, val, obj_info[fid], &sb, builders, records)
		delete(val)
	}

	// Metadatos XMP (solo si se configuraron)
	if plan.metadata_id > 0 {
		xmp := build_xmp_content(doc.metadata_info)
		defer delete(xmp)
		xmp_bytes := transmute([]byte)xmp
		offset := i64(strings.builder_len(sb))

		if enc_ctx != nil && enc_ctx.encrypt_metadata {
			// Cifrar el stream XMP cuando el flag está activo
			enc_xmp := encrypt_data(enc_ctx.file_key, xmp_bytes)
			defer delete(enc_xmp)
			fmt.sbprintf(&sb, "%d 0 obj\n<< /Type /Metadata /Subtype /XML /Filter /Crypt /Length %d >>\nstream\n", plan.metadata_id, len(enc_xmp))
			strings.write_bytes(&sb, enc_xmp)
			strings.write_string(&sb, "\nendstream\nendobj\n")
		} else {
			write_xmp_stream(&sb, plan.metadata_id, xmp_bytes)
		}
		records[plan.metadata_id] = Xref_Record{.Direct, offset, 0}
	}

	// /Encrypt
	if plan.encrypt_id > 0 && enc_ctx != nil {
		offset := i64(strings.builder_len(sb))
		write_encrypt_dict(&sb, plan.encrypt_id, enc_ctx)
		records[plan.encrypt_id] = Xref_Record{.Direct, offset, 0}
	}

	// Campos de firma: appearance XObject + /Sig + /Widget
	for i in 0 ..< len(doc.sig_fields) {
		sf  := doc.sig_fields[i]
		ids := &plan.sig_ids[i]

		// XObject de apariencia (obligatorio en PDF 2.0 si Rect > 0)
		if ids.ap_id > 0 {
			offset_ap := i64(strings.builder_len(sb))
			write_sig_appearance_xobject(&sb, ids.ap_id, sf.rect)
			records[ids.ap_id] = Xref_Record{.Direct, offset_ap, 0}
		}

		// Objeto /Sig con placeholders
		base := strings.builder_len(sb)
		ids.placeholder = write_sig_value_object(&sb, ids.sig_value_id, sf, base)
		records[ids.sig_value_id] = Xref_Record{.Direct, i64(base), 0}

		// Widget con /T único y /AP condicional
		page_id  := plan.page_ids[sf.page] if sf.page < len(plan.page_ids) else plan.page_ids[0]
		offset_w := i64(strings.builder_len(sb))
		write_sig_widget(&sb, ids.widget_id, ids.sig_value_id, page_id, i, sf.rect, ids.ap_id)
		records[ids.widget_id] = Xref_Record{.Direct, offset_w, 0}
	}

	// AcroForm
	if plan.acroform_id > 0 {
		val := serialize_non_stream_value(plan.acroform_id, plan, doc, -1, "")
		defer delete(val)
		route_non_stream(plan.acroform_id, val, obj_info[plan.acroform_id], &sb, builders, records)
	}

	// Volcar ObjStm builders
	for i in 0 ..< len(builders) {
		if objstm_len(&builders[i]) == 0 { continue }

		written, ok := objstm_write(&builders[i], &sb)
		if !ok { continue }

		records[written.own_id] = Xref_Record{.Direct, written.offset, 0}
		for entry in written.entries {
			records[entry.obj_id] = Xref_Record{.Compressed, i64(written.own_id), entry.index}
		}
		delete(written.entries)
	}

	return
}

// ── Etapa 5: Build XRef ───────────────────────────────────────

pipeline_build_xref :: proc(sb: ^strings.Builder, plan: ^Render_Plan, doc: ^Pdf_Document, records: []Xref_Record) {
	xref_offset := i64(strings.builder_len(sb^))
	records[plan.xref_stream_id] = Xref_Record{.Direct, xref_offset, 0}

	write_xref_stream(sb, plan.xref_stream_id, records, plan.catalog_id, doc.file_id, plan.encrypt_id)

	fmt.sbprintf(sb, "startxref\n%d\n%%%%EOF", xref_offset)
}

// ── Punto de entrada de serialización ────────────────────────

serialize_document :: proc(doc: ^Pdf_Document, filename: string) -> bool {
	page_data, ok := pipeline_collect(doc)
	if !ok { return false }

	plan, next_id := pipeline_assign(doc, page_data)
	defer render_plan_destroy(&plan)

	pipeline_classify(&plan, &next_id)

	enc_ctx: Encryption_Context
	enc_ptr: ^Encryption_Context = nil

	if sec, has_sec := doc.security.?; has_sec {
		ctx, enc_ok := setup_encryption(sec)
		if enc_ok {
			enc_ctx = ctx
			enc_ptr = &enc_ctx
			plan.encrypt_id = next_id
			append(&plan.objects, Obj_Descriptor{
				id = next_id,
				role = .Encrypt_Dict,
				in_objstm = false,
				objstm_idx = -1,
			})
			next_id += 1
		}
	}

	plan.xref_stream_id = next_id; next_id += 1
	plan.total_ids = next_id - 1

	sb, records := pipeline_render(doc, &plan, enc_ptr)
	defer strings.builder_destroy(&sb)
	defer delete(records)

	pipeline_build_xref(&sb, &plan, doc, records)

	_ = os.write_entire_file(filename, sb.buf[:])
	return true
}
