#+private
package winpdfgenerator

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"

WINANSI_TO_UNICODE := [128]rune {
	0x20AC,	0x0000,	0x201A,	0x0192,	0x201E,	0x2026,	0x2020,	0x2021,	0x02C6,	0x2030,	0x0160,	0x2039,	0x0152,	0x0000,	0x017D,	0x0000,	0x0000,	0x2018,	0x2019,	0x201C,	0x201D,	0x2022,	0x2013,	0x2014,	0x02DC,	0x2122,	0x0161,	0x203A,	0x0153,	0x0000,	0x017E,	0x0178,	0x00A0,	0x00A1,	0x00A2,	0x00A3,	0x00A4,	0x00A5,	0x00A6,	0x00A7,	0x00A8,	0x00A9,	0x00AA,	0x00AB,	0x00AC,	0x00AD,	0x00AE,	0x00AF,	0x00B0,	0x00B1,	0x00B2,	0x00B3,	0x00B4,	0x00B5,	0x00B6,	0x00B7,	0x00B8,	0x00B9,	0x00BA,	0x00BB,	0x00BC,	0x00BD,	0x00BE,	0x00BF,	0x00C0,	0x00C1,	0x00C2,	0x00C3,	0x00C4,	0x00C5,	0x00C6,	0x00C7,	0x00C8,	0x00C9,	0x00CA,	0x00CB,	0x00CC,	0x00CD,	0x00CE,	0x00CF,	0x00D0,	0x00D1,	0x00D2,	0x00D3,	0x00D4,	0x00D5,	0x00D6,	0x00D7,	0x00D8, 0x00D9,	0x00DA,	0x00DB,	0x00DC,	0x00DD,	0x00DE,	0x00DF,	0x00E0,	0x00E1,	0x00E2,	0x00E3,	0x00E4,	0x00E5,	0x00E6,	0x00E7,	0x00E8,	0x00E9,	0x00EA,	0x00EB,	0x00EC,	0x00ED,	0x00EE,	0x00EF,
	0x00F0,	0x00F1,	0x00F2,	0x00F3,	0x00F4,	0x00F5,	0x00F6,	0x00F7,	0x00F8,	0x00F9,	0x00FA,	0x00FB,	0x00FC,	0x00FD,	0x00FE,	0x00FF,
}

core_document_create :: proc() -> ^Pdf_Document {
	doc := new(Pdf_Document)
	doc.pages = make([dynamic]^Pdf_Page)
	doc.objects = make([dynamic]Pdf_Object_Entry)
	doc.sig_fields = make([dynamic]^Sig_Field)
	doc.xref_table = make([dynamic]XRef_Entry)
	doc.embedded_fonts = make(map[string]Embedded_Font)
	doc.file_id[0] = generate_file_id("seed_1")
	doc.file_id[1] = generate_file_id("seed_2")
	doc.next_obj_num = 1
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

	for key, emb in doc.embedded_fonts {
		delete(emb.ttf_data)
	}
	delete(doc.embedded_fonts)

	delete(doc.objects)
	delete(doc.sig_fields)
	delete(doc.xref_table)

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
		fmt.printf(
			"[WinPdfGenerator] ERROR: No se pudo cargar la fuente incrustada en la ruta: %s\n",
			string(path),
		)
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
		if i >= 128 {
			codepoint = WINANSI_TO_UNICODE[i - 128]
		}
		advance, lsb: c.int
		stbtt.GetCodepointHMetrics(&info, codepoint, &advance, &lsb)
		emb.widths[i] = f32(advance) * scale
	}

	doc.embedded_fonts[emb.alias] = emb
	return true
}

core_page_add_text :: proc(page: ^Pdf_Page, text: cstring, x, y: f32, font_name: cstring, font_size: f32, text_color_rgb: [3] f32) {
	if page == nil do return

	obj := Pdf_Page_Text_Object {
		text      = strings.clone_from_cstring(text),
		x         = x,
		y         = y,
		font_name = strings.clone_from_cstring(font_name),
		font_size = font_size,
		color     = Color_RGB{text_color_rgb[0], text_color_rgb[1], text_color_rgb[2]},
	}
	append(&page.items, Content_Item{data = obj})
}

core_page_add_image :: proc(page: ^Pdf_Page, path: cstring, x, y, width, height: f32) {
	if page == nil do return
	img := Pdf_Page_Image_Object {
		image_path = strings.clone_from_cstring(path),
		x          = x,
		y          = y,
		width      = width,
		height     = height,
	}
	append(&page.items, Content_Item{data = img})
}

core_document_set_metadata :: proc(doc: ^Pdf_Document, title, author, subject, keywords, creator, producer, creation_date, mod_date: cstring) {
	if doc == nil do return
	if doc.metadata_info.title         != "" do delete(doc.metadata_info.title)
	if doc.metadata_info.author        != "" do delete(doc.metadata_info.author)
	if doc.metadata_info.subject       != "" do delete(doc.metadata_info.subject)
	if doc.metadata_info.keywords      != "" do delete(doc.metadata_info.keywords)
	if doc.metadata_info.creator       != "" do delete(doc.metadata_info.creator)
	if doc.metadata_info.producer      != "" do delete(doc.metadata_info.producer)
	if doc.metadata_info.creation_date != "" do delete(doc.metadata_info.creation_date)
	if doc.metadata_info.mod_date      != "" do delete(doc.metadata_info.mod_date)

	if title    != nil do doc.metadata_info.title    = strings.clone_from_cstring(title)
	if author   != nil do doc.metadata_info.author   = strings.clone_from_cstring(author)
	if subject  != nil do doc.metadata_info.subject  = strings.clone_from_cstring(subject)
	if keywords != nil do doc.metadata_info.keywords = strings.clone_from_cstring(keywords)
	if creator  != nil do doc.metadata_info.creator  = strings.clone_from_cstring(creator)
	if producer != nil do doc.metadata_info.producer = strings.clone_from_cstring(producer)

	if creation_date != nil && len(string(creation_date)) > 0 {
		doc.metadata_info.creation_date = strings.clone_from_cstring(creation_date)
	}
	if mod_date != nil && len(string(mod_date)) > 0 {
		doc.metadata_info.mod_date = strings.clone_from_cstring(mod_date)
	}
}

Image_Resource :: struct {
	alias:      string,
	obj_id:     int,
	smask_id:   int,
	width:      int,
	height:     int,
	channels:   int,
	rgb_data:   []byte,
	alpha_data: []byte,
}

Page_Resources :: struct {
	font_map: map[string]string,
	images:   [dynamic]Image_Resource,
}

System_Font_Metrics :: struct {
	bbox:         [4]int,
	ascent:       int,
	descent:      int,
	cap_height:   int,
	stem_v:       int,
	flags:        int,
	italic_angle: int,
}

HELVETICA_WIDTHS :: [224]int{
	278, 278, 355, 556, 556, 889, 667, 222, 333, 333, 389, 584, 278, 333, 278, 278,
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
	1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
	667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
	222, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
	556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584, 278,
	556, 278, 222, 556, 333, 1000, 556, 556, 278, 1000, 667, 333, 1000, 278, 500, 667,
	278, 278, 222, 222, 333, 333, 350, 556, 1000, 222, 1000, 500, 333, 944, 278, 500,
	278, 333, 556, 556, 556, 556, 260, 556, 333, 737, 370, 556, 584, 333, 737, 333,
	400, 584, 333, 333, 333, 556, 537, 278, 333, 333, 365, 556, 834, 834, 834, 611,
	667, 667, 667, 667, 667, 667, 1000, 722, 667, 667, 667, 667, 278, 278, 278, 278,
	722, 722, 778, 778, 778, 778, 778, 584, 778, 722, 722, 722, 722, 667, 667, 611,
	556, 556, 556, 556, 556, 556, 889, 500, 556, 556, 556, 556, 278, 278, 278, 278,
	556, 556, 556, 556, 556, 556, 556, 584, 611, 556, 556, 556, 556, 500, 556, 500,
}

get_type1_metrics :: proc(font_name: string) -> System_Font_Metrics {
	switch font_name {
	case "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique":
		return {bbox = {-166, -225, 1000, 931}, ascent = 718,  descent = -207, cap_height = 718, stem_v = 88, flags = 32, italic_angle = 0}
	case "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic":
		return {bbox = {-168, -218, 1000, 898}, ascent = 683,  descent = -217, cap_height = 662, stem_v = 84, flags = 34, italic_angle = 0}
	case "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique":
		return {bbox = {-23,  -250,  715,  805}, ascent = 629, descent = -157, cap_height = 562, stem_v = 51, flags = 33, italic_angle = 0}
	case:
		return {bbox = {-100, -200, 1000, 900}, ascent = 800,  descent = -200, cap_height = 700, stem_v = 80, flags = 32, italic_angle = 0}
	}
}

write_font_widths :: proc(sb: ^strings.Builder, font_name: string) {
	strings.write_string(sb, "[")
	switch font_name {
	case "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique":
		for w in HELVETICA_WIDTHS {
			fmt.sbprintf(sb, "%d ", w)
		}
	case:
		for _ in 0..<224 {
			strings.write_string(sb, "600 ")
		}
	}
	strings.write_string(sb, "]")
}

write_type1_font_resource :: proc(sb: ^strings.Builder, alias, ps_name, orig_name: string) {
	m := get_type1_metrics(orig_name)
	fmt.sbprintf(sb,
		"/%s << /Type /Font /Subtype /Type1 /BaseFont /%s /Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 255 /Widths ",
		alias, ps_name)
	write_font_widths(sb, orig_name)
	fmt.sbprintf(sb,
		" /FontDescriptor << /Type /FontDescriptor /FontName /%s /Flags %d /FontBBox [%d %d %d %d] /ItalicAngle %d /Ascent %d /Descent %d /CapHeight %d /StemV %d >> >> ",
		ps_name, m.flags,
		m.bbox[0], m.bbox[1], m.bbox[2], m.bbox[3],
		m.italic_angle, m.ascent, m.descent, m.cap_height, m.stem_v,
	)
}

write_truetype_font_resource :: proc(sb: ^strings.Builder, alias, ps_name: string) {
	fmt.sbprintf(sb,
		"/%s << /Type /Font /Subtype /TrueType /BaseFont /%s /Encoding /WinAnsiEncoding /FirstChar 32 /LastChar 255 /Widths ",
		alias, ps_name)
	write_font_widths(sb, "")
	fmt.sbprintf(sb,
		" /FontDescriptor << /Type /FontDescriptor /FontName /%s /Flags 32 /FontBBox [-100 -200 1000 900] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 800 /StemV 80 >> >> ",
		ps_name,
	)
}

serialize_document :: proc(doc: ^Pdf_Document, filename: string) -> bool {
	n := len(doc.pages)

	content_strs := make([]string, n)
	res_strs := make([]string, n)
	page_res := make([]Page_Resources, n)

	defer {
		for s in content_strs {delete(s)}
		for s in res_strs {delete(s)}
		delete(content_strs)
		delete(res_strs)

		for pr in page_res {
			for _, alias in pr.font_map {delete(alias)}
			delete(pr.font_map)
			for img in pr.images {
				delete(img.alias)
				delete(img.rgb_data)
				if img.alpha_data != nil do delete(img.alpha_data)
			}
			delete(pr.images)
		}
		delete(page_res)
	}

	next_id := 3 + 2 * n

	for page, i in doc.pages {
		pr := &page_res[i]
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
				if img_data != nil {
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
						img_res.obj_id = next_id
						next_id += 1
					} else if channels == 2 || channels == 4 {
						color_ch := int(channels) - 1
						img_res.rgb_data = make([]byte, pixels * color_ch)
						img_res.alpha_data = make([]byte, pixels)

						for p in 0 ..< pixels {
							for c_idx in 0 ..< color_ch {
								img_res.rgb_data[p * color_ch + c_idx] =
									src[p * int(channels) + c_idx]
							}
							img_res.alpha_data[p] = src[p * int(channels) + color_ch]
						}

						img_res.smask_id = next_id
						next_id += 1
						img_res.obj_id = next_id
						next_id += 1
					}

					append(&pr.images, img_res)
				} else {
					fmt.printf(
						"[WinPdfGenerator] ERROR: No se pudo cargar la imagen: %s\n",
						v.image_path,
					)
				}
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
					img_res := pr.images[img_idx]
					img_idx += 1

					alias_name := fmt.aprintf("/%s", img_res.alias)
					write_image_do(&csb, Pdf_Name(alias_name), v.x, v.y, v.width, v.height)
					delete(alias_name)
				}
			}
		}
		content_strs[i] = strings.clone(strings.to_string(csb))
		strings.builder_destroy(&csb)
	}

	for key in doc.embedded_fonts {
		emb := &doc.embedded_fonts[key]
		emb.file_obj_id = next_id; next_id += 1
		emb.widths_obj_id = next_id; next_id += 1
		emb.desc_obj_id = next_id; next_id += 1
		emb.font_obj_id = next_id; next_id += 1
	}

	for page, i in doc.pages {
		pr := &page_res[i]
		frsb := strings.builder_make()

		if len(pr.font_map) > 0 {
			strings.write_string(&frsb, "/Font << ")
			for fname, alias in pr.font_map {
				if fname in doc.embedded_fonts {
					emb := doc.embedded_fonts[fname]
					fmt.sbprintf(&frsb, "/%s %d 0 R ", alias, emb.font_obj_id)
				} else {
					ps_name, _ := strings.replace_all(fname, " ", "")
					is_type1 :=
						fname == "Helvetica"             || fname == "Helvetica-Bold"       ||
						fname == "Helvetica-Oblique"     || fname == "Helvetica-BoldOblique" ||
						fname == "Times-Roman"           || fname == "Times-Bold"            ||
						fname == "Times-Italic"          || fname == "Times-BoldItalic"      ||
						fname == "Courier"               || fname == "Courier-Bold"          ||
						fname == "Courier-Oblique"       || fname == "Courier-BoldOblique"   ||
						fname == "Symbol"                || fname == "ZapfDingbats"

					if is_type1 {
						write_type1_font_resource(&frsb, alias, ps_name, fname)
					} else {
						write_truetype_font_resource(&frsb, alias, ps_name)
					}

					delete(ps_name)
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

		res_strs[i] = strings.clone(strings.to_string(frsb))
		strings.builder_destroy(&frsb)
	}

	metadata_id := next_id; next_id += 1

	total := next_id - 1
	offsets := make([]i64, total)
	defer delete(offsets)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	write_header(&sb)

	offsets[0] = i64(strings.builder_len(sb))
	fmt.sbprintf(&sb, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R /Metadata %d 0 R >>\nendobj\n", metadata_id)

	offsets[1] = i64(strings.builder_len(sb))
	kids_sb := strings.builder_make()
	defer strings.builder_destroy(&kids_sb)
	for i in 0 ..< n {fmt.sbprintf(&kids_sb, "%d 0 R ", 3 + i)}
	fmt.sbprintf(
		&sb,
		"2 0 obj\n<< /Type /Pages /Count %d /Kids [%s] >>\nendobj\n",
		n,
		strings.to_string(kids_sb),
	)

	for page, i in doc.pages {
		offsets[2 + i] = i64(strings.builder_len(sb))
		pid := 3 + i
		cid := 3 + n + i
		fmt.sbprintf(
			&sb,
			"%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [%.4f %.4f %.4f %.4f] /Contents %d 0 R /Resources << %s>> >>\nendobj\n",
			pid,
			page.media_box.llx,
			page.media_box.lly,
			page.media_box.urx,
			page.media_box.ury,
			cid,
			res_strs[i],
		)
	}

	for i in 0 ..< n {
		offsets[2 + n + i] = i64(strings.builder_len(sb))
		cid := 3 + n + i
		content := content_strs[i]
		fmt.sbprintf(
			&sb,
			"%d 0 obj\n<< /Length %d >>\nstream\n%sendstream\nendobj\n",
			cid,
			len(content),
			content,
		)
	}

	for pr in page_res {
		for img in pr.images {
			if img.smask_id != 0 {
				comp_alpha, _ := filter_apply_flate(img.alpha_data)
				use_alpha_flate := len(comp_alpha) < len(img.alpha_data)
				alpha_payload := use_alpha_flate ? comp_alpha : img.alpha_data

				offsets[img.smask_id - 1] = i64(strings.builder_len(sb))
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
				delete(comp_alpha)
			}

			comp_rgb, _ := filter_apply_flate(img.rgb_data)
			use_rgb_flate := len(comp_rgb) < len(img.rgb_data)
			rgb_payload := use_rgb_flate ? comp_rgb : img.rgb_data
			color_space := img.channels == 1 || img.channels == 2 ? "/DeviceGray" : "/DeviceRGB"

			offsets[img.obj_id - 1] = i64(strings.builder_len(sb))
			hdr := strings.builder_make()
			fmt.sbprintf(&hdr,
				"%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent 8",
				img.obj_id, img.width, img.height, color_space)
			if use_rgb_flate   { strings.write_string(&hdr, " /Filter /FlateDecode") }
			if img.smask_id != 0 { fmt.sbprintf(&hdr, " /SMask %d 0 R", img.smask_id) }
			fmt.sbprintf(&hdr, " /Length %d >>\nstream\n", len(rgb_payload))
			strings.write_string(&sb, strings.to_string(hdr))
			strings.builder_destroy(&hdr)

			strings.write_bytes(&sb, rgb_payload)
			strings.write_string(&sb, "\nendstream\nendobj\n")
			delete(comp_rgb)
		}
	}

	for key, emb in doc.embedded_fonts {
		offsets[emb.file_obj_id - 1] = i64(strings.builder_len(sb))
		fmt.sbprintf(
			&sb,
			"%d 0 obj\n<< /Length %d /Length1 %d >>\nstream\n",
			emb.file_obj_id,
			len(emb.ttf_data),
			len(emb.ttf_data),
		)
		strings.write_bytes(&sb, emb.ttf_data)
		strings.write_string(&sb, "\nendstream\nendobj\n")

		offsets[emb.widths_obj_id - 1] = i64(strings.builder_len(sb))
		fmt.sbprintf(&sb, "%d 0 obj\n[ ", emb.widths_obj_id)
		for i in 32 ..= 255 {
			fmt.sbprintf(&sb, "%.0f ", emb.widths[i])
		}
		strings.write_string(&sb, "]\nendobj\n")

		offsets[emb.desc_obj_id - 1] = i64(strings.builder_len(sb))
		safe_alias, _ := strings.replace_all(emb.alias, " ", "")
		pdf_font_name := fmt.aprintf("AAAAAA+%s", safe_alias)

		fmt.sbprintf(
			&sb,
			"%d 0 obj\n<< /Type /FontDescriptor /FontName /%s /Flags %d /FontBBox [%.0f %.0f %.0f %.0f] /ItalicAngle %.0f /Ascent %.0f /Descent %.0f /CapHeight %.0f /StemV %.0f /FontFile2 %d 0 R >>\nendobj\n",
			emb.desc_obj_id,
			pdf_font_name,
			emb.flags,
			emb.bbox.llx,
			emb.bbox.lly,
			emb.bbox.urx,
			emb.bbox.ury,
			emb.italic_angle,
			emb.ascent,
			emb.descent,
			emb.cap_height,
			emb.stem_v,
			emb.file_obj_id,
		)

		offsets[emb.font_obj_id - 1] = i64(strings.builder_len(sb))
		fmt.sbprintf(
			&sb,
			"%d 0 obj\n<< /Type /Font /Subtype /TrueType /BaseFont /%s /FirstChar 32 /LastChar 255 /Widths %d 0 R /FontDescriptor %d 0 R /Encoding /WinAnsiEncoding >>\nendobj\n",
			emb.font_obj_id,
			pdf_font_name,
			emb.widths_obj_id,
			emb.desc_obj_id,
		)

		delete(safe_alias)
		delete(pdf_font_name)
	}

	offsets[metadata_id - 1] = i64(strings.builder_len(sb))
	write_xmp_object(&sb, metadata_id, doc.metadata_info)

	xref_offset := i64(strings.builder_len(sb))

	entries := make([]XRef_Entry, total)
	defer delete(entries)
	for off, idx in offsets {
		entries[idx] = XRef_Entry {
			offset = off,
			gen    = 0,
			in_use = true,
		}
	}
	write_xref(&sb, entries)

	write_trailer(&sb, total, 1, xref_offset, doc.file_id[0][:], doc.file_id[1][:])

	_ = os.write_entire_file(filename, sb.buf[:])
	return true
}
