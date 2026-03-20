package winpdfgenerator

// Representa una referencia indirecta (ej: 3 0 R) [10, 11]
PDF_Ref :: struct {
	id:  int,
	gen: int,
}

// Estructura interna para rastrear offsets en la tabla Xref [12]
XRef_Entry :: struct {
	offset: i64,
	gen:    int,
	in_use: bool,
}

// Tipos de objetos básicos definidos en la especificación [8, 10]
PDF_Object_Type :: enum {
	Boolean,
	Integer,
	Real,
	String,
	Name,
	Array,
	Dictionary,
	Stream,
	Null,
}
