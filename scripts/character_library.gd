extends RefCounted
class_name CharacterLibrary

## Descoberta automática de personagens jogáveis. Qualquer modelo (.fbx/.glb/
## .gltf) solto na pasta abaixo vira um personagem do jogo — sem editar código.
## O menu de seleção e o spawner leem esta lista.

const CHARACTERS_DIR := "res://assets/models/playable_characters"
const MODEL_EXTENSIONS := ["fbx", "glb", "gltf"]

## Lista [{ "name": String, "path": String }], ordenada por nome. `name` é o
## nome do arquivo sem extensão (ex.: "Aceu.fbx" -> "Aceu").
static func discover() -> Array:
	var result: Array = []
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir == null:
		push_warning("CharacterLibrary: pasta não encontrada: " + CHARACTERS_DIR)
		return result

	for file_name in dir.get_files():
		# No editor os modelos aparecem como "Aceu.fbx" (+ "Aceu.fbx.import");
		# em build exportado o importado pode ter sufixo ".remap"/".import".
		var clean := file_name
		if clean.ends_with(".import") or clean.ends_with(".remap"):
			clean = clean.get_basename()
		var ext := clean.get_extension().to_lower()
		if not MODEL_EXTENSIONS.has(ext):
			continue
		var path := CHARACTERS_DIR + "/" + clean
		if not ResourceLoader.exists(path):
			continue
		var name := clean.get_file().get_basename()
		if _has_name(result, name):
			continue
		result.append({ "name": name, "path": path })

	result.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return result

static func _has_name(list: Array, name: String) -> bool:
	for entry in list:
		if entry["name"] == name:
			return true
	return false
