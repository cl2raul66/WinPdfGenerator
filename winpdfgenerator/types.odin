#+private
package winpdfgenerator

Pdf_Object :: union {
	bool,
	i64,
	f32,
	string,
	Pdf_Name,
	[dynamic]Pdf_Object,
	Pdf_Dict,
	Pdf_Stream,
	Pdf_Ref,
	Pdf_Null,
}

Pdf_Name   :: distinct string
Pdf_Null   :: struct {}
Pdf_Dict   :: map[Pdf_Name]Pdf_Object

Pdf_Ref :: struct {
	id:  int,
	gen: int,
}

Pdf_Stream :: struct {
	dict:     Pdf_Dict,
	contents: []byte,
}

Rect :: struct {
	llx, lly, urx, ury: f32,
}

XRef_Entry :: struct {
	offset: i64,
	gen:    int,
	in_use: bool,
}

Pdf_Object_Entry :: struct {
	num: i64,
	gen: int,
	obj: Pdf_Object,
}

Path_Command_Kind :: enum {
	Move_To,
	Line_To,
	Curve_To,
	Close,
}

Path_Command :: struct {
	kind: Path_Command_Kind,
	pts:  [6]f32,
}

Pdf_Page_Text_Object :: struct {
	text:      string,
	x, y:      f32,
	font_name: string,
	font_size: f32,
	color:     Color_RGB,
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

Content_Item :: struct {
	data: union {
		Pdf_Page_Text_Object,
		Pdf_Page_Path_Object,
		Pdf_Page_Image_Object,
	},
}

Annotation_Highlight :: struct {
	rects:  [dynamic]Rect,
	color:  Color_RGB,
	author: string,
}

Pdf_Page :: struct {
	media_box:   Rect,
	resources:   Pdf_Dict,
	items:       [dynamic]Content_Item,
	annotations: [dynamic]Annotation,
}

Embedded_Font :: struct {
	alias:         string,
	ttf_data:      []byte,
	ascent:        f32,
	descent:       f32,
	cap_height:    f32,
	bbox:          Rect,
	italic_angle:  f32,
	stem_v:        f32,
	flags:         u32,
	widths:        [256]f32,
	font_obj_id:   int,
	desc_obj_id:   int,
	widths_obj_id: int,
	file_obj_id:   int,
}

Pdf_Document :: struct {
	catalog:       Pdf_Dict,
	root_ref:      Pdf_Ref,
	pages:         [dynamic]^Pdf_Page,
	metadata_info: Pdf_Info,
	file_id:       [2][16]byte,
	security:    Maybe(Security_Handler),
	sig_fields:  [dynamic]^Sig_Field,
	xref_table:  [dynamic]XRef_Entry,
	objects:     [dynamic]Pdf_Object_Entry,
	next_obj_num: i64,
	embedded_fonts: map[string]Embedded_Font,
}
