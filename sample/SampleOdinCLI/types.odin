package winpdfgenerator

PDF_Ref :: struct { id, gen: int }

XRef_Entry :: struct {
    offset: i64,
    gen:    int,
    in_use: bool,
}

Rect :: struct { left, top, right, bottom: f32 }

Color_RGB :: struct { r, g, b: f32 }

Page_Info :: struct {
    page_num:     int,
    width_pts:    int,
    height_pts:   int,
    content_rect: Maybe(Rect),
}

Page_Info_Builder :: struct { info: Page_Info }

Paper_Size :: enum i32 {
    Letter = 0,
    Legal  = 1,
    A4     = 2,
    A3     = 3,
}

Print_Attributes :: struct {
    paper_size:    Paper_Size,
    margin_top:    f32,
    margin_bottom: f32,
    margin_left:   f32,
    margin_right:  f32,
    color:         bool,
}

Print_Attributes_Builder :: struct { attrs: Print_Attributes }

Pdf_Page_Text_Object :: struct {
    text:      string,
    x, y:      f32,
    font_name: string,
    font_size: f32,
    color:     Color_RGB,
}

Path_Command_Kind :: enum { Move_To, Line_To, Curve_To, Close }

Path_Command :: struct {
    kind: Path_Command_Kind,
    pts:  [3][2]f32,
}

Pdf_Page_Path_Object :: struct {
    commands:     [dynamic]Path_Command,
    fill_color:   Color_RGB,
    stroke_color: Color_RGB,
    line_width:   f32,
    filled:       bool,
    stroked:      bool,
}

Pdf_Page_Image_Object :: struct {
    image_path:    string,
    x, y:          f32,
    width, height: f32,
}

Content_Item_Kind :: enum { Text, Path, Image }

Content_Item :: struct {
    kind:  Content_Item_Kind,
    text:  ^Pdf_Page_Text_Object,
    path:  ^Pdf_Page_Path_Object,
    image: ^Pdf_Page_Image_Object,
}

Highlight_Annotation :: struct {
    rects:  [dynamic]Rect,
    color:  Color_RGB,
    author: string,
}

Stamp_Annotation :: struct {
    rect:    Rect,
    icon:    string,
    subject: string,
}

Free_Text_Annotation :: struct {
    rect:      Rect,
    content:   string,
    font_size: f32,
    color:     Color_RGB,
}

Annotation_Kind :: enum { Highlight, Stamp, Free_Text }

Annotation :: struct {
    kind:      Annotation_Kind,
    highlight: ^Highlight_Annotation,
    stamp:     ^Stamp_Annotation,
    free_text: ^Free_Text_Annotation,
}

Form_Widget_Kind :: enum i32 {
    Text_Field   = 0,
    Check_Box    = 1,
    Radio_Button = 2,
    Combo_Box    = 3,
    List_Box     = 4,
    Push_Button  = 5,
    Signature    = 6,
}

Form_Widget_Info :: struct {
    kind:         Form_Widget_Kind,
    id:           int,
    rect:         Rect,
    partial_name: string,
    read_only:    bool,
    required:     bool,
    max_length:   int,
    list_options: []string,
    checked:      bool,
}

Form_Widget_Builder :: struct { info: Form_Widget_Info }

Pdf_Page_Link_Content :: struct {
    rect: Rect,
    uri:  string,
}

Pdf_Page_Goto_Link_Content :: struct {
    rect:      Rect,
    dest_page: int,
    dest_x:    f32,
    dest_y:    f32,
}

Pdf_Page :: struct {
    info:         Page_Info,
    items:        [dynamic]Content_Item,
    annotations:  [dynamic]^Annotation,
    links:        [dynamic]^Pdf_Page_Link_Content,
    goto_links:   [dynamic]^Pdf_Page_Goto_Link_Content,
    form_widgets: [dynamic]^Form_Widget_Info,
    doc:          ^Pdf_Document,
}

Pdf_Document :: struct {
    pages:       [dynamic]^Pdf_Page,
    print_attrs: Maybe(Print_Attributes),
}
