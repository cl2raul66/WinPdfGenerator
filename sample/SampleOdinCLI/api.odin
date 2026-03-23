package winpdfgenerator

import "core:c"

// ════════════════════════════════════════════════════════════════
// PdfDocument
// ════════════════════════════════════════════════════════════════

@(export)
pdf_document_create :: proc() -> ^Pdf_Document {
    doc := new(Pdf_Document)
    doc.pages = make([dynamic]^Pdf_Page)
    return doc
}

@(export)
pdf_document_write_to_file :: proc(doc: ^Pdf_Document, filename: cstring) -> c.bool {
    return c.bool(serialize_document(doc, string(filename)))
}

@(export)
pdf_document_close :: proc(doc: ^Pdf_Document) {
    for page in doc.pages { page_destroy(page) }
    delete(doc.pages)
    free(doc)
}

// ════════════════════════════════════════════════════════════════
// PageInfo.Builder
// ════════════════════════════════════════════════════════════════

@(export)
page_info_builder_create :: proc(page_num, width_pts, height_pts: c.int) -> ^Page_Info_Builder {
    b := new(Page_Info_Builder)
    b.info = Page_Info{
        page_num   = int(page_num),
        width_pts  = int(width_pts),
        height_pts = int(height_pts),
    }
    return b
}

@(export) page_info_builder_create_letter :: proc(n: c.int) -> ^Page_Info_Builder { return page_info_builder_create(n, 612, 792)  }
@(export) page_info_builder_create_a4     :: proc(n: c.int) -> ^Page_Info_Builder { return page_info_builder_create(n, 595, 842)  }
@(export) page_info_builder_create_legal  :: proc(n: c.int) -> ^Page_Info_Builder { return page_info_builder_create(n, 612, 1008) }

@(export)
page_info_builder_set_content_rect :: proc(b: ^Page_Info_Builder, left, top, right, bottom: c.float) {
    b.info.content_rect = Rect{f32(left), f32(top), f32(right), f32(bottom)}
}

@(export)
page_info_builder_build :: proc(b: ^Page_Info_Builder) -> ^Page_Info {
    info := new(Page_Info)
    info^ = b.info
    free(b)
    return info
}

@(export)
page_info_free :: proc(info: ^Page_Info) { free(info) }

// ════════════════════════════════════════════════════════════════
// Page lifecycle
// ════════════════════════════════════════════════════════════════

@(export)
pdf_document_start_page :: proc(doc: ^Pdf_Document, info: ^Page_Info) -> ^Pdf_Page {
    page := new(Pdf_Page)
    page^ = Pdf_Page{
        info         = info^,
        items        = make([dynamic]Content_Item),
        annotations  = make([dynamic]^Annotation),
        links        = make([dynamic]^Pdf_Page_Link_Content),
        goto_links   = make([dynamic]^Pdf_Page_Goto_Link_Content),
        form_widgets = make([dynamic]^Form_Widget_Info),
        doc          = doc,
    }
    return page
}

@(export)
pdf_document_finish_page :: proc(doc: ^Pdf_Document, page: ^Pdf_Page) {
    append(&doc.pages, page)
}

// ════════════════════════════════════════════════════════════════
// PdfPageTextObject
// ════════════════════════════════════════════════════════════════

@(export)
pdf_page_text_object_create :: proc(
    text: cstring, x, y: c.float,
    font_name: cstring, font_size: c.float,
) -> ^Pdf_Page_Text_Object {
    obj := new(Pdf_Page_Text_Object)
    obj^ = Pdf_Page_Text_Object{
        text = string(text), x = f32(x), y = f32(y),
        font_name = string(font_name), font_size = f32(font_size),
        color = Color_RGB{0, 0, 0},
    }
    return obj
}

@(export)
pdf_page_text_object_set_color :: proc(obj: ^Pdf_Page_Text_Object, r, g, b: c.float) {
    obj.color = Color_RGB{f32(r), f32(g), f32(b)}
}

@(export)
pdf_page_add_text_object :: proc(page: ^Pdf_Page, obj: ^Pdf_Page_Text_Object) {
    append(&page.items, Content_Item{kind = .Text, text = obj})
}

@(export)
pdf_page_text_object_free :: proc(obj: ^Pdf_Page_Text_Object) { free(obj) }

// ════════════════════════════════════════════════════════════════
// PdfPagePathObject
// ════════════════════════════════════════════════════════════════

@(export)
pdf_page_path_object_create :: proc() -> ^Pdf_Page_Path_Object {
    obj := new(Pdf_Page_Path_Object)
    obj^ = Pdf_Page_Path_Object{
        commands     = make([dynamic]Path_Command),
        stroke_color = Color_RGB{0, 0, 0},
        line_width   = 1.0,
        stroked      = true,
    }
    return obj
}

@(export)
pdf_page_path_object_move_to :: proc(obj: ^Pdf_Page_Path_Object, x, y: c.float) {
    append(&obj.commands, Path_Command{kind = .Move_To, pts = {{f32(x), f32(y)}, {}, {}}})
}

@(export)
pdf_page_path_object_line_to :: proc(obj: ^Pdf_Page_Path_Object, x, y: c.float) {
    append(&obj.commands, Path_Command{kind = .Line_To, pts = {{f32(x), f32(y)}, {}, {}}})
}

@(export)
pdf_page_path_object_curve_to :: proc(obj: ^Pdf_Page_Path_Object, cx1, cy1, cx2, cy2, ex, ey: c.float) {
    append(&obj.commands, Path_Command{
        kind = .Curve_To,
        pts  = {{f32(cx1), f32(cy1)}, {f32(cx2), f32(cy2)}, {f32(ex), f32(ey)}},
    })
}

@(export)
pdf_page_path_object_close :: proc(obj: ^Pdf_Page_Path_Object) {
    append(&obj.commands, Path_Command{kind = .Close})
}

@(export)
pdf_page_path_object_set_stroke_color :: proc(obj: ^Pdf_Page_Path_Object, r, g, b: c.float) {
    obj.stroke_color = Color_RGB{f32(r), f32(g), f32(b)}
    obj.stroked = true
}

@(export)
pdf_page_path_object_set_fill_color :: proc(obj: ^Pdf_Page_Path_Object, r, g, b: c.float) {
    obj.fill_color = Color_RGB{f32(r), f32(g), f32(b)}
    obj.filled = true
}

@(export)
pdf_page_path_object_set_line_width :: proc(obj: ^Pdf_Page_Path_Object, w: c.float) {
    obj.line_width = f32(w)
}

@(export)
pdf_page_add_path_object :: proc(page: ^Pdf_Page, obj: ^Pdf_Page_Path_Object) {
    append(&page.items, Content_Item{kind = .Path, path = obj})
}

@(export)
pdf_page_path_object_free :: proc(obj: ^Pdf_Page_Path_Object) {
    delete(obj.commands)
    free(obj)
}

// ════════════════════════════════════════════════════════════════
// PdfPageImageObject
// ════════════════════════════════════════════════════════════════

@(export)
pdf_page_image_object_create :: proc(
    image_path: cstring, x, y, width, height: c.float,
) -> ^Pdf_Page_Image_Object {
    obj := new(Pdf_Page_Image_Object)
    obj^ = Pdf_Page_Image_Object{
        image_path = string(image_path),
        x = f32(x), y = f32(y), width = f32(width), height = f32(height),
    }
    return obj
}

@(export)
pdf_page_add_image_object :: proc(page: ^Pdf_Page, obj: ^Pdf_Page_Image_Object) {
    append(&page.items, Content_Item{kind = .Image, image = obj})
}

@(export)
pdf_page_image_object_free :: proc(obj: ^Pdf_Page_Image_Object) { free(obj) }

// ════════════════════════════════════════════════════════════════
// Annotations
// ════════════════════════════════════════════════════════════════

@(export)
highlight_annotation_create :: proc(r, g, b: c.float) -> ^Annotation {
    ann := new(Annotation)
    ann.kind = .Highlight
    ann.highlight = new(Highlight_Annotation)
    ann.highlight^ = Highlight_Annotation{
        color = Color_RGB{f32(r), f32(g), f32(b)},
        rects = make([dynamic]Rect),
    }
    return ann
}

@(export)
highlight_annotation_add_rect :: proc(ann: ^Annotation, left, top, right, bottom: c.float) {
    append(&ann.highlight.rects, Rect{f32(left), f32(top), f32(right), f32(bottom)})
}

@(export)
highlight_annotation_set_author :: proc(ann: ^Annotation, author: cstring) {
    ann.highlight.author = string(author)
}

@(export)
stamp_annotation_create :: proc(
    left, top, right, bottom: c.float, icon, subject: cstring,
) -> ^Annotation {
    ann := new(Annotation)
    ann.kind = .Stamp
    ann.stamp = new(Stamp_Annotation)
    ann.stamp^ = Stamp_Annotation{
        rect    = Rect{f32(left), f32(top), f32(right), f32(bottom)},
        icon    = string(icon),
        subject = string(subject),
    }
    return ann
}

@(export)
free_text_annotation_create :: proc(
    left, top, right, bottom: c.float,
    content: cstring, font_size: c.float, r, g, b: c.float,
) -> ^Annotation {
    ann := new(Annotation)
    ann.kind = .Free_Text
    ann.free_text = new(Free_Text_Annotation)
    ann.free_text^ = Free_Text_Annotation{
        rect      = Rect{f32(left), f32(top), f32(right), f32(bottom)},
        content   = string(content),
        font_size = f32(font_size),
        color     = Color_RGB{f32(r), f32(g), f32(b)},
    }
    return ann
}

@(export)
pdf_page_add_annotation :: proc(page: ^Pdf_Page, ann: ^Annotation) {
    append(&page.annotations, ann)
}

@(export)
annotation_free :: proc(ann: ^Annotation) { annotation_destroy(ann) }

// ════════════════════════════════════════════════════════════════
// FormWidgetInfo.Builder
// ════════════════════════════════════════════════════════════════

@(export)
form_widget_builder_create :: proc(
    kind: c.int, id: c.int, left, top, right, bottom: c.float,
) -> ^Form_Widget_Builder {
    b := new(Form_Widget_Builder)
    b.info = Form_Widget_Info{
        kind = Form_Widget_Kind(kind),
        id   = int(id),
        rect = Rect{f32(left), f32(top), f32(right), f32(bottom)},
    }
    return b
}

@(export)
form_widget_builder_set_name :: proc(b: ^Form_Widget_Builder, name: cstring) {
    b.info.partial_name = string(name)
}

@(export)
form_widget_builder_set_read_only :: proc(b: ^Form_Widget_Builder, v: c.bool) { b.info.read_only = bool(v) }

@(export)
form_widget_builder_set_required :: proc(b: ^Form_Widget_Builder, v: c.bool) { b.info.required = bool(v) }

@(export)
form_widget_builder_set_max_length :: proc(b: ^Form_Widget_Builder, v: c.int) { b.info.max_length = int(v) }

@(export)
form_widget_builder_build :: proc(b: ^Form_Widget_Builder) -> ^Form_Widget_Info {
    info := new(Form_Widget_Info)
    info^ = b.info
    free(b)
    return info
}

@(export)
pdf_page_add_form_widget :: proc(page: ^Pdf_Page, w: ^Form_Widget_Info) {
    append(&page.form_widgets, w)
}

@(export)
form_widget_free :: proc(w: ^Form_Widget_Info) { free(w) }

// ════════════════════════════════════════════════════════════════
// PdfPageLinkContent / PdfPageGotoLinkContent
// ════════════════════════════════════════════════════════════════

@(export)
pdf_page_link_content_create :: proc(
    left, top, right, bottom: c.float, uri: cstring,
) -> ^Pdf_Page_Link_Content {
    link := new(Pdf_Page_Link_Content)
    link^ = Pdf_Page_Link_Content{
        rect = Rect{f32(left), f32(top), f32(right), f32(bottom)},
        uri  = string(uri),
    }
    return link
}

@(export)
pdf_page_add_link :: proc(page: ^Pdf_Page, link: ^Pdf_Page_Link_Content) {
    append(&page.links, link)
}

@(export)
pdf_page_link_content_free :: proc(link: ^Pdf_Page_Link_Content) { free(link) }

@(export)
pdf_page_goto_link_content_create :: proc(
    left, top, right, bottom: c.float,
    dest_page: c.int, dest_x, dest_y: c.float,
) -> ^Pdf_Page_Goto_Link_Content {
    link := new(Pdf_Page_Goto_Link_Content)
    link^ = Pdf_Page_Goto_Link_Content{
        rect      = Rect{f32(left), f32(top), f32(right), f32(bottom)},
        dest_page = int(dest_page),
        dest_x    = f32(dest_x),
        dest_y    = f32(dest_y),
    }
    return link
}

@(export)
pdf_page_add_goto_link :: proc(page: ^Pdf_Page, link: ^Pdf_Page_Goto_Link_Content) {
    append(&page.goto_links, link)
}

@(export)
pdf_page_goto_link_content_free :: proc(link: ^Pdf_Page_Goto_Link_Content) { free(link) }

// ════════════════════════════════════════════════════════════════
// PrintedPdfDocument
// ════════════════════════════════════════════════════════════════

@(export)
print_attributes_builder_create :: proc() -> ^Print_Attributes_Builder {
    b := new(Print_Attributes_Builder)
    b.attrs = Print_Attributes{paper_size = .Letter, color = true}
    return b
}

@(export)
print_attributes_builder_set_paper_size :: proc(b: ^Print_Attributes_Builder, size: c.int) {
    b.attrs.paper_size = Paper_Size(size)
}

@(export)
print_attributes_builder_set_margins :: proc(b: ^Print_Attributes_Builder, top, bottom, left, right: c.float) {
    b.attrs.margin_top    = f32(top)
    b.attrs.margin_bottom = f32(bottom)
    b.attrs.margin_left   = f32(left)
    b.attrs.margin_right  = f32(right)
}

@(export)
print_attributes_builder_set_color :: proc(b: ^Print_Attributes_Builder, v: c.bool) {
    b.attrs.color = bool(v)
}

@(export)
print_attributes_builder_build :: proc(b: ^Print_Attributes_Builder) -> ^Print_Attributes {
    attrs := new(Print_Attributes)
    attrs^ = b.attrs
    free(b)
    return attrs
}

@(export)
print_attributes_free :: proc(attrs: ^Print_Attributes) { free(attrs) }

@(export)
printed_pdf_document_create :: proc(attrs: ^Print_Attributes) -> ^Pdf_Document {
    doc := pdf_document_create()
    doc.print_attrs = attrs^
    free(attrs)
    return doc
}

@(export)
printed_pdf_document_start_page :: proc(doc: ^Pdf_Document) -> ^Pdf_Page {
    width, height := 612, 792
    if attrs, ok := doc.print_attrs.?; ok {
        width, height = paper_size_pts(attrs.paper_size)
    }
    b := page_info_builder_create(
        c.int(len(doc.pages) + 1), c.int(width), c.int(height),
    )
    if attrs, ok := doc.print_attrs.?; ok {
        page_info_builder_set_content_rect(b,
            c.float(attrs.margin_left),
            c.float(attrs.margin_top),
            c.float(f32(width)  - attrs.margin_right),
            c.float(f32(height) - attrs.margin_bottom),
        )
    }
    info := page_info_builder_build(b)
    defer page_info_free(info)
    return pdf_document_start_page(doc, info)
}

@(private)
paper_size_pts :: proc(size: Paper_Size) -> (int, int) {
    switch size {
    case .Letter: return 612, 792
    case .Legal:  return 612, 1008
    case .A4:     return 595, 842
    case .A3:     return 842, 1191
    }
    return 612, 792
}
