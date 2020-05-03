extends Node


# Get hold of the brushes, including random brushes (subdirectories and % files
# in them, non % files get loaded independently.) nyaaa
# Returns a list of [
# [non random single png files in the root subdir],
# {
# map of subdirectories to lists of files for
# the randomised brush - if a directory contains no
# randomised files then it is not included in this.
# },
# {
# map of subdirectories to lists of files inside of them
# that are not for randomised brushes.
# }
# ]
# The separation of nonrandomised and randomised files
# in subdirectories allows different XDG_DATA_DIR overriding
# for each nyaa.
#
# Returns null if the directory gave an error opening.
#
func get_brush_files_from_directory(directory: String): # -> Array
	var base_png_files := []  # list of files in the base directory
	var subdirectories := []  # list of subdirectories to process.

	var randomised_subdir_files_map : Dictionary = {}
	var nonrandomised_subdir_files_map : Dictionary = {}

	var main_directory : Directory = Directory.new()
	var err := main_directory.open(directory)
	if err != OK:
		return null

	# Build first the list of base png files and all subdirectories to
	# scan later (skip navigational . and ..)
	main_directory.list_dir_begin(true)
	var fname : String = main_directory.get_next()
	while fname != "":
		if main_directory.current_is_dir():
			subdirectories.append(fname)
		else: # Filter for pngs
			if fname.get_extension().to_lower() == "png":
				base_png_files.append(fname)

		# go to next
		fname = main_directory.get_next()
	main_directory.list_dir_end()

	# Now we iterate over subdirectories!
	for subdirectory in subdirectories:
		var the_directory : Directory = Directory.new()

		# Holds names of files that make this
		# a component of a randomised brush ^.^
		var randomised_files := []

		# Non-randomise-indicated image files
		var non_randomised_files := []

		the_directory.open(directory.plus_file(subdirectory))
		the_directory.list_dir_begin(true)
		var curr_file := the_directory.get_next()

		while curr_file != "":
			# only do stuff if we are actually dealing with a file
			# and png one at that nya
			if !the_directory.current_is_dir() and curr_file.get_extension().to_lower() == "png":
				# if we are a random element, add
				if "%" in curr_file:
					randomised_files.append(curr_file)
				else:
					non_randomised_files.append(curr_file)
			curr_file = the_directory.get_next()

		the_directory.list_dir_end()

		# Add these to the maps nyaa
		if len(randomised_files) > 0:
			randomised_subdir_files_map[subdirectory] = randomised_files
		if len(non_randomised_files) > 0:
			nonrandomised_subdir_files_map[subdirectory] = non_randomised_files
	# We are done generating the maps!
	return [base_png_files, randomised_subdir_files_map, nonrandomised_subdir_files_map]


# Add a randomised brush from the given list of files as a source.
# The tooltip name is what shows up on the tooltip
# and is probably in this case the name of the containing
# randomised directory.
func add_randomised_brush(fpaths : Array, tooltip_name : String) -> void:
	# Attempt to load the images from the file paths.
	var loaded_images : Array = []
	for filen in fpaths:
		var image := Image.new()
		var err := image.load(filen)
		if err == OK:
			image.convert(Image.FORMAT_RGBA8)
			loaded_images.append(image)

	# If any images were successfully loaded, then
	# we create the randomised brush button, copied
	# from find_brushes.

	if len(loaded_images) > 0:  # actually have images
		# to use.
		# take initial image...
		var first_image : Image = loaded_images.pop_front()

		# The index which this random brush will be at
		var next_random_brush_index := Global.file_brush_container.get_child_count()

		Global.custom_brushes.append(first_image)
		Global.create_brush_button(first_image, Global.Brush_Types.RANDOM_FILE, tooltip_name)
	#	# Process the rest
		for remaining_image in loaded_images:
			var brush_button = Global.file_brush_container.get_child(next_random_brush_index)
			brush_button.random_brushes.append(remaining_image)

# Add a plain brush from the given path to the list of brushes.
# Taken, again, from find_brushes
func add_plain_brush(path: String, tooltip_name: String) -> void:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return
	# do the standard conversion thing...
	image.convert(Image.FORMAT_RGBA8)
	Global.custom_brushes.append(image)
	Global.create_brush_button(image, Global.Brush_Types.FILE, tooltip_name)


# Import brushes, in priority order, from the paths in question in priority order
# i.e. with an override system
# We use a very particular override system here where, for randomised brushes
# the directories containing them get overridden, but for nonrandomised files
# (including in directories containing randomised components too), the override
# is on a file-by-file basis nyaaaa ^.^
func import_brushes(priority_ordered_search_path: Array) -> void:
	# Maps for files in the base directory (name : true)
	var processed_basedir_paths : Dictionary = {}
	var randomised_brush_subdirectories : Dictionary = {}
	# Map from a subdirectory to a map similar to processed_basedir_files
	# i.e. once a filename has been dealt with, set it to true.
	var processed_subdir_paths : Dictionary = {}

	# Sets of results of get_brush_files_from_directory
	var all_available_paths : Array = []
	for directory in priority_ordered_search_path:
		all_available_paths.append(get_brush_files_from_directory(directory))

	# Now to process. Note these are in order of the
	# priority, as intended nyaa :)
	for i in range(len(all_available_paths)):
		var available_brush_file_information = all_available_paths[i]
		var current_main_directory: String = priority_ordered_search_path[i]
		if available_brush_file_information != null:
			# The brush files in the main directory
			var main_directory_file_paths : Array = available_brush_file_information[0]
			# The subdirectory/list-of-randomised-brush-files
			# map for this directory
			var randomised_brush_subdirectory_map : Dictionary = available_brush_file_information[1]
			# Map for subdirectories to non-randomised-brush files nyaa
			var nonrandomised_brush_subdirectory_map : Dictionary = available_brush_file_information[2]

			# Iterate over components and do stuff with them! nyaa
			# first for the main directory path...
			for subfile in main_directory_file_paths:
				if not (subfile in processed_basedir_paths):
					add_plain_brush(
						current_main_directory.plus_file(subfile),
						subfile.get_basename()
					)
					processed_basedir_paths[subfile] = true

			# Iterate over the randomised brush files nyaa
			for randomised_subdir in randomised_brush_subdirectory_map:
				if not (randomised_subdir in randomised_brush_subdirectories):
					var full_paths := []
					# glue the proper path onto the single file names in the
					# random brush directory data system, so they can be
					# opened nya
					for non_extended_path in randomised_brush_subdirectory_map[randomised_subdir]:
						full_paths.append(current_main_directory.plus_file(
							randomised_subdir
						).plus_file(
							non_extended_path
						))
					# Now load!
					add_randomised_brush(full_paths, randomised_subdir)
					# and mark that we are done in the overall map ^.^
					randomised_brush_subdirectories[randomised_subdir] = true
			# Now to iterate over the nonrandom brush files inside directories
			for nonrandomised_subdir in nonrandomised_brush_subdirectory_map:
				# initialise the set-map for this one if not already present :)
				if not (nonrandomised_subdir in processed_subdir_paths):
					processed_subdir_paths[nonrandomised_subdir] = {}
				# Get the paths within this subdirectory to check if they are
				# processed or not and if not, then process them.
				var relpaths_of_contained_nonrandom_brushes : Array = nonrandomised_brush_subdirectory_map[nonrandomised_subdir]
				for relative_path in relpaths_of_contained_nonrandom_brushes:
					if not (relative_path in processed_subdir_paths[nonrandomised_subdir]):
						# We are not yet processed
						var full_path : String = current_main_directory.plus_file(
							nonrandomised_subdir
						).plus_file(
							relative_path
						)
						# Add the path with the tooltip including the directory
						add_plain_brush(full_path, nonrandomised_subdir.plus_file(
							relative_path
						).get_basename())
						# Mark this as a processed relpath
						processed_subdir_paths[nonrandomised_subdir][relative_path] = true

	Global.brushes_from_files = Global.custom_brushes.size()


func import_patterns(priority_ordered_search_path: Array) -> void:
	for path in priority_ordered_search_path:
		var pattern_list := []
		var dir := Directory.new()
		dir.open(path)
		dir.list_dir_begin()
		var curr_file := dir.get_next()
		while curr_file != "":
			if curr_file.get_extension().to_lower() == "png":
				pattern_list.append(curr_file)
			curr_file = dir.get_next()
		dir.list_dir_end()

		for pattern in pattern_list:
			var image := Image.new()
			var err := image.load(path.plus_file(pattern))
			if err == OK:
				image.convert(Image.FORMAT_RGBA8)
				Global.patterns.append(image)

				var pattern_button : BaseButton = load("res://src/UI/PatternButton.tscn").instance()
				pattern_button.image = image
				var pattern_tex := ImageTexture.new()
				pattern_tex.create_from_image(image, 0)
				pattern_button.get_child(0).texture = pattern_tex
				pattern_button.hint_tooltip = pattern
				pattern_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				Global.patterns_popup.get_node("ScrollContainer/PatternContainer").add_child(pattern_button)

			if Global.patterns.size() > 0:
				var image_size = Global.patterns[0].get_size()

				Global.pattern_left_image = Global.patterns[0]
				var pattern_left_tex := ImageTexture.new()
				pattern_left_tex.create_from_image(Global.pattern_left_image, 0)
				Global.left_fill_pattern_container.get_child(0).get_child(0).texture = pattern_left_tex
				Global.left_fill_pattern_container.get_child(2).get_child(1).max_value = image_size.x - 1
				Global.left_fill_pattern_container.get_child(3).get_child(1).max_value = image_size.y - 1

				Global.pattern_right_image = Global.patterns[0]
				var pattern_right_tex := ImageTexture.new()
				pattern_right_tex.create_from_image(Global.pattern_right_image, 0)
				Global.right_fill_pattern_container.get_child(0).get_child(0).texture = pattern_right_tex
				Global.right_fill_pattern_container.get_child(2).get_child(1).max_value = image_size.x - 1
				Global.right_fill_pattern_container.get_child(3).get_child(1).max_value = image_size.y - 1


func import_gpl(path : String) -> Palette:
	var result : Palette = null
	var file = File.new()
	if file.file_exists(path):
		file.open(path, File.READ)
		var text = file.get_as_text()
		var lines = text.split('\n')
		var line_number := 0
		var comments := ""
		for line in lines:
			# Check if valid Gimp Palette Library file
			if line_number == 0:
				if line != "GIMP Palette":
					break
				else:
					result = Palette.new()
					var name_start = path.find_last('/') + 1
					var name_end = path.find_last('.')
					if name_end > name_start:
						result.name = path.substr(name_start, name_end - name_start)

			# Comments
			if line.begins_with('#'):
				comments += line.trim_prefix('#') + '\n'
				pass
			elif line_number > 0 && line.length() >= 12:
				line = line.replace("\t", " ")
				var color_data : PoolStringArray = line.split(" ", false, 4)
				var red : float = color_data[0].to_float() / 255.0
				var green : float = color_data[1].to_float() / 255.0
				var blue : float = color_data[2].to_float() / 255.0
				var color = Color(red, green, blue)
				result.add_color(color, color_data[3])
			line_number += 1

		if result:
			result.comments = comments
		file.close()

	return result


func import_png_palette(path: String) -> Palette:
	var result: Palette = null

	var image := Image.new()
	var err := image.load(path)
	if err != OK: # An error occured
		return null

	var height: int = image.get_height()
	var width: int = image.get_width()

	result = Palette.new()

	# Iterate all pixels and store unique colors to palete
	image.lock()
	for y in range(0, height):
		for x in range(0, width):
			var color: Color = image.get_pixel(x, y)
			if not result.has_color(color):
				result.add_color(color, "#" + color.to_html())
	image.unlock()

	var name_start = path.find_last('/') + 1
	var name_end = path.find_last('.')
	if name_end > name_start:
		result.name = path.substr(name_start, name_end - name_start)

	return result