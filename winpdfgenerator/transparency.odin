#+private
//#+feature dynamic-literals
package winpdfgenerator

import "core:fmt"
import "core:strings"

Blend_Mode :: enum {
	Normal,
	Multiply,
	Screen,
	Overlay,
	Darken,
	Lighten,
	Color_Dodge,
	Color_Burn,
	Hard_Light,
	Soft_Light,
	Difference,
	Exclusion,
	Hue,
	Saturation,
	Color,
	Luminosity,
}

Soft_Mask_Kind :: enum {
	Alpha,
	Luminosity,
}

Soft_Mask :: struct {
	kind:     Soft_Mask_Kind,
	group:    Pdf_Ref,
	backdrop: Maybe(Color_RGB),
	transfer: Maybe(Pdf_Ref),
}

Ext_G_State :: struct {
	blend_mode:     Maybe(Blend_Mode),
	fill_alpha:     Maybe(f32),
	stroke_alpha:   Maybe(f32),
	alpha_is_shape: Maybe(bool),
	soft_mask:      Maybe(Soft_Mask),
	text_knockout:  Maybe(bool),
	overprint_fill: Maybe(bool),
	overprint_strk: Maybe(bool),
	overprint_mode: Maybe(int),
}

Transparency_Group :: struct {
	color_space: Maybe(Pdf_Object),
	isolated:    bool,
	knockout:    bool,
}

// CORRECCIÓN: fmt.aprintf("/%v", bm) producía /Color_Dodge en lugar de /ColorDodge.
// §Table 135 especifica nombres PDF en CamelCase.
@(private)
blend_mode_to_name :: proc(bm: Blend_Mode) -> Pdf_Name {
	switch bm {
	case .Normal:      return Pdf_Name("/Normal")
	case .Multiply:    return Pdf_Name("/Multiply")
	case .Screen:      return Pdf_Name("/Screen")
	case .Overlay:     return Pdf_Name("/Overlay")
	case .Darken:      return Pdf_Name("/Darken")
	case .Lighten:     return Pdf_Name("/Lighten")
	case .Color_Dodge: return Pdf_Name("/ColorDodge")
	case .Color_Burn:  return Pdf_Name("/ColorBurn")
	case .Hard_Light:  return Pdf_Name("/HardLight")
	case .Soft_Light:  return Pdf_Name("/SoftLight")
	case .Difference:  return Pdf_Name("/Difference")
	case .Exclusion:   return Pdf_Name("/Exclusion")
	case .Hue:         return Pdf_Name("/Hue")
	case .Saturation:  return Pdf_Name("/Saturation")
	case .Color:       return Pdf_Name("/Color")
	case .Luminosity:  return Pdf_Name("/Luminosity")
	}
	return Pdf_Name("/Normal")
}

write_transparency_group :: proc(g: Transparency_Group) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/Type"] = Pdf_Name("/Group")
	d["/S"]    = Pdf_Name("/Transparency")
	d["/I"]    = g.isolated
	d["/K"]    = g.knockout
	if cs, ok := g.color_space.?; ok { d["/CS"] = cs }
	return d
}

ext_g_state_to_pdf :: proc(gs: Ext_G_State) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/Type"] = Pdf_Name("/ExtGState")

	if bm,  ok := gs.blend_mode.?;     ok { d["/BM"]  = blend_mode_to_name(bm) }
	if val, ok := gs.fill_alpha.?;     ok { d["/ca"]  = val }
	if val, ok := gs.stroke_alpha.?;   ok { d["/CA"]  = val }
	if val, ok := gs.alpha_is_shape.?; ok { d["/AIS"] = val }
	if val, ok := gs.text_knockout.?;  ok { d["/TK"]  = val }
	if val, ok := gs.overprint_fill.?; ok { d["/op"]  = val }
	if val, ok := gs.overprint_strk.?; ok { d["/OP"]  = val }
	if val, ok := gs.overprint_mode.?; ok { d["/OPM"] = i64(val) }

	if sm, ok := gs.soft_mask.?; ok {
		smask_dict := make(Pdf_Dict)
		smask_dict["/Type"] = Pdf_Name("/Mask")
		smask_dict["/S"]    = sm.kind == .Alpha ? Pdf_Name("/Alpha") : Pdf_Name("/Luminosity")
		smask_dict["/G"]    = sm.group
		if bc, ok := sm.backdrop.?; ok {
			// CORRECCIÓN: [dynamic]Pdf_Object literal requería #+feature dynamic-literals.
			bc_arr := make([dynamic]Pdf_Object)
			append(&bc_arr, bc.r)
			append(&bc_arr, bc.g)
			append(&bc_arr, bc.b)
			smask_dict["/BC"] = bc_arr
		}
		if tr, ok := sm.transfer.?; ok { smask_dict["/TR"] = tr }
		d["/SMask"] = smask_dict
	}
	return d
}

write_set_ext_gstate :: proc(sb: ^strings.Builder, name: Pdf_Name) {
	fmt.sbprintf(sb, "%s gs\n", name)
}
