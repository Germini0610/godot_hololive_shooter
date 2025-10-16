extends Node
class_name Attribute

## 屬性枚舉
enum Type {
	RED,
	BLUE,
	GREEN,
	BLACK,
	WHITE,
	GOLD,
	SILVER
}

## 屬性相剋倍率表
const MULTIPLIER_TABLE = {
	Type.RED: {
		Type.RED: 1.0,
		Type.BLUE: 0.5,
		Type.GREEN: 2.0,
		Type.BLACK: 1.0,
		Type.WHITE: 1.0,
		Type.GOLD: 1.0,
		Type.SILVER: 1.0
	},
	Type.BLUE: {
		Type.RED: 2.0,
		Type.BLUE: 1.0,
		Type.GREEN: 0.5,
		Type.BLACK: 1.0,
		Type.WHITE: 1.0,
		Type.GOLD: 1.0,
		Type.SILVER: 1.0
	},
	Type.GREEN: {
		Type.RED: 0.5,
		Type.BLUE: 2.0,
		Type.GREEN: 1.0,
		Type.BLACK: 1.0,
		Type.WHITE: 1.0,
		Type.GOLD: 1.0,
		Type.SILVER: 1.0
	},
	Type.BLACK: {
		Type.RED: 1.0,
		Type.BLUE: 1.0,
		Type.GREEN: 1.0,
		Type.BLACK: 1.0,
		Type.WHITE: 2.0,
		Type.GOLD: 0.5,
		Type.SILVER: 1.0
	},
	Type.WHITE: {
		Type.RED: 1.0,
		Type.BLUE: 1.0,
		Type.GREEN: 1.0,
		Type.BLACK: 2.0,
		Type.WHITE: 1.0,
		Type.GOLD: 1.0,
		Type.SILVER: 0.5
	},
	Type.GOLD: {
		Type.RED: 1.5,
		Type.BLUE: 1.5,
		Type.GREEN: 1.5,
		Type.BLACK: 2.0,
		Type.WHITE: 1.5,
		Type.GOLD: 1.0,
		Type.SILVER: 1.0
	},
	Type.SILVER: {
		Type.RED: 1.5,
		Type.BLUE: 1.5,
		Type.GREEN: 1.5,
		Type.BLACK: 1.5,
		Type.WHITE: 2.0,
		Type.GOLD: 1.0,
		Type.SILVER: 1.0
	}
}

## 取得屬性相剋倍率
static func get_multiplier(attacker_attr: Type, defender_attr: Type) -> float:
	if MULTIPLIER_TABLE.has(attacker_attr) and MULTIPLIER_TABLE[attacker_attr].has(defender_attr):
		return MULTIPLIER_TABLE[attacker_attr][defender_attr]
	return 1.0

## 取得屬性名稱
static func get_attribute_name(attr: Type) -> String:
	match attr:
		Type.RED: return "RED"
		Type.BLUE: return "BLUE"
		Type.GREEN: return "GREEN"
		Type.BLACK: return "BLACK"
		Type.WHITE: return "WHITE"
		Type.GOLD: return "GOLD"
		Type.SILVER: return "SILVER"
		_: return "UNKNOWN"

## 取得屬性顏色
static func get_attribute_color(attr: Type) -> Color:
	match attr:
		Type.RED: return Color.RED
		Type.BLUE: return Color.BLUE
		Type.GREEN: return Color.GREEN
		Type.BLACK: return Color.BLACK
		Type.WHITE: return Color.WHITE
		Type.GOLD: return Color.GOLD
		Type.SILVER: return Color.SILVER
		_: return Color.GRAY
