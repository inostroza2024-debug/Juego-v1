extends RefCounted
# Datos de la sede. ex: VERIFIED / HISTORICAL / APPROXIMATE. lv: 0 = piso 1, 1 = piso 2

const VERSION := "V0.6"

const EXL := {
	"VERIFIED": "Confirmado (información institucional)",
	"HISTORICAL": "Antecedente histórico, por verificar",
	"APPROXIMATE": "Aproximado, por verificar",
}

const LUGARES := [
	{"id": "acceso", "n": "Acceso", "x": 0, "z": 16, "r": 4, "ex": "APPROXIMATE", "t": "Ingreso a la sede (Froilán Roa 7107, La Florida). Desde aquí se abre el patio central."},
	{"id": "patio", "n": "Patio central", "x": 0, "z": 0, "r": 9, "ex": "VERIFIED", "t": "Patio central de unos 1.000 m², espacio de circulación y encuentro entre los edificios."},
	{"id": "punto", "n": "Punto Estudiantil", "x": -10, "z": -3, "r": 5, "ex": "VERIFIED", "t": "El Punto Estudiantil está ubicado en el patio central. Atiende trámites y consultas de estudiantes."},
	{"id": "biblioteca", "n": "Biblioteca", "x": -18, "z": -27, "r": 7, "ex": "VERIFIED", "t": "Biblioteca y espacios de estudio. Antecedentes históricos mencionan salas de lectura y cubículos de estudio."},
	{"id": "sala", "n": "Sala de clases", "x": 6, "z": -27, "r": 7, "ex": "VERIFIED", "t": "La sede dispone de múltiples salas de clases. Un antecedente histórico registra 48; el número actual debe verificarse."},
	{"id": "lab", "n": "Laboratorio de computación", "x": 18, "z": -27, "r": 7, "ex": "VERIFIED", "t": "Laboratorios para formación práctica. Un antecedente histórico registra 9 laboratorios de computación."},
	{"id": "piso2", "n": "Segundo piso", "x": 22.8, "z": -14.9, "r": 2.5, "lv": 1, "ex": "APPROXIMATE", "t": "Segundo nivel del edificio principal (4 pisos en total). Los pisos 3 y 4 llegan en versiones futuras."},
	{"id": "taller", "n": "Taller de Diseño", "x": -18, "z": -27, "r": 7, "lv": 1, "ex": "HISTORICAL", "t": "Antecedentes históricos registran 3 talleres de Diseño. Su ubicación actual debe verificarse."},
	{"id": "saltec", "n": "Sala tecnológica", "x": 6, "z": -27, "r": 7, "lv": 1, "ex": "HISTORICAL", "t": "Antecedente histórico de una sala tecnológica. Ubicación y características actuales por verificar."},
	{"id": "audit", "n": "Auditorio", "x": 18, "z": -27, "r": 7, "lv": 1, "ex": "HISTORICAL", "t": "Antecedente histórico de un auditorio. Su ubicación y configuración actual deben verificarse."},
]

const OBJETOS := [
	{"n": "Portal de acceso", "x": 0, "z": 14, "r": 3, "ex": "APPROXIMATE", "t": "Portal de ingreso. Dirección: Froilán Roa 7107, La Florida. La sede funciona desde 2003."},
	{"n": "Banca del patio", "x": 9, "z": 4, "r": 2.5, "ex": "APPROXIMATE", "t": "Banca para descansar entre clases."},
	{"n": "Segundo edificio", "x": 22, "z": 2, "r": 5, "ex": "VERIFIED", "t": "Segundo edificio de 3 pisos (unos 2.519 m²). Su interior llega en versiones futuras."},
	{"n": "Edificio principal", "x": 0, "z": -9, "r": 3, "ex": "VERIFIED", "t": "Edificio principal de 4 pisos (unos 6.296 m²)."},
	{"n": "Escaleras", "x": 12, "z": -14.9, "r": 2.2, "ex": "APPROXIMATE", "t": "Escalera con baranda de vidrio hacia el segundo piso. Sube caminando por ella."},
	{"n": "Cartel Biblioteca", "x": -18, "z": -16.5, "r": 2.5, "ex": "APPROXIMATE", "t": "Puerta de la Biblioteca."},
	{"n": "Sala 101", "x": 6, "z": -16.5, "r": 2.5, "ex": "APPROXIMATE", "t": "Número de sala de ejemplo: la numeración real se cargará cuando se verifique."},
	{"n": "Mesón de atención", "x": -10, "z": -2.1, "r": 2.6, "ex": "APPROXIMATE", "t": "Mesón del Punto Estudiantil, en el patio central."},
	{"n": "Computadores", "x": 18, "z": -24, "r": 3, "ex": "APPROXIMATE", "t": "Puestos de trabajo con computador."},
	{"n": "Panel de avisos", "x": 0, "z": -16.6, "r": 2, "ex": "APPROXIMATE", "t": "Panel con avisos y actividades para estudiantes."},
	{"n": "Máquina expendedora", "x": -22, "z": -13.8, "r": 2.2, "ex": "APPROXIMATE", "t": "Snacks y bebidas para las pausas entre clases."},
	{"n": "Mesas de dibujo", "x": -18, "z": -28, "r": 4, "lv": 1, "ex": "APPROXIMATE", "t": "Mesas de trabajo del taller de Diseño."},
	{"n": "Rack de red", "x": 6, "z": -34, "r": 3, "lv": 1, "ex": "APPROXIMATE", "t": "Equipos de red: la sede tiene formación en Informática, redes y telecomunicaciones."},
	{"n": "Escenario", "x": 18, "z": -33.5, "r": 3, "lv": 1, "ex": "APPROXIMATE", "t": "Escenario y pantalla del auditorio."},
	{"n": "Baranda del patio", "x": 0, "z": -13, "r": 3, "lv": 1, "ex": "APPROXIMATE", "t": "Desde la galería del segundo piso se ve el patio central."},
]
