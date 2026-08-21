extends Button

var build_template : building_template
var building_manager : Node

func setup(building: building_template, manager : Node):
	build_template = building
	text = building.name
	building_manager = manager

func clicked():
	building_manager.select_building(build_template)
