extends RefCounted
## Costs are combat Power (战意); prices are expedition Runes (灵纹).
const DATA := {
  "strike": {
    "name": "折光斩",
    "cost": 0,
    "type": "攻击",
    "color": "eab483",
    "attack": 0.4,
    "flat": 1,
    "text": "造成攻击力40%+1伤害，获得1战意。",
    "energy": 1
  },
  "guard": {
    "name": "守势",
    "cost": 0,
    "type": "技能",
    "color": "78c9c2",
    "block": 5,
    "text": "获得5+防御/4+敏捷/8格挡。免费。"
  },
  "rupture": {
    "name": "血线",
    "cost": 1,
    "type": "攻击",
    "color": "e194a6",
    "attack": 0.45,
    "flat": 1,
    "bleed": 3,
    "text": "造成攻击力45%+1伤害，施加流血3，持续2回合。",
    "price": 3,
    "school": "血契"
  },
  "break": {
    "name": "破阵",
    "cost": 2,
    "type": "攻击",
    "color": "eab483",
    "attack": 0.9,
    "flat": 4,
    "stagger": 7,
    "vulnerable": 2,
    "text": "造成攻击力90%+4伤害，削韧7，易伤2回合（增伤25%）。",
    "price": 4,
    "school": "锋刃"
  },
  "focus": {
    "name": "灵光",
    "cost": 0,
    "type": "技能",
    "color": "b4a2e0",
    "draw": 2,
    "exhaust": true,
    "text": "抽2张牌。消耗：本场不再抽到。已打出的牌回合结束才入弃牌堆。"
  },
  "dash": {
    "name": "掠影",
    "cost": 0,
    "type": "技能",
    "color": "78c9c2",
    "block": 2,
    "momentum": 0.2,
    "text": "获得格挡及1战意；下一击增伤20%+移动力×3%，蓄势最多80%。",
    "energy": 1
  },
  "heavy": {
    "name": "断碑",
    "cost": 2,
    "type": "攻击",
    "color": "eab483",
    "attack": 1.5,
    "flat": 4,
    "stagger": 6,
    "text": "长剑专属。造成攻击力150%+4伤害，削韧6。"
  },
  "quick": {
    "name": "鸦羽",
    "cost": 1,
    "type": "攻击",
    "color": "e194a6",
    "attack": 0.65,
    "flat": 2,
    "draw": 1,
    "text": "短刃专属。造成攻击力65%+2伤害，抽1张牌。",
    "price": 3,
    "school": "锋刃"
  },
  "shadowstep": {
    "name": "影步",
    "cost": 0,
    "type": "技能",
    "color": "b4a2e0",
    "block": 3,
    "momentum": 0.35,
    "exhaust": true,
    "text": "影步词条专属。格挡、1战意，蓄势35%+移动力×3%。消耗。",
    "energy": 1
  },
  "reap": {
    "name": "收割",
    "cost": 2,
    "type": "攻击",
    "color": "e194a6",
    "attack": 1.0,
    "flat": 2,
    "bleed_bonus": 10,
    "text": "造成攻击力100%+2伤害；目标流血时额外+10。",
    "price": 4,
    "school": "血契"
  },
  "riposte": {
    "name": "交锋",
    "cost": 1,
    "type": "攻击",
    "color": "78c9c2",
    "attack": 0.5,
    "flat": 1,
    "block": 5,
    "text": "造成攻击力50%+1伤害，同时获得格挡。",
    "price": 3,
    "school": "壁垒"
  },
  "echo": {
    "name": "心刃",
    "cost": 2,
    "type": "攻击",
    "color": "b4a2e0",
    "attack": 0.25,
    "will": 0.28,
    "flat": 2,
    "text": "造成攻击力25%+意志28%+2伤害，无视护甲。",
    "price": 4,
    "school": "秘仪"
  },
  "bastion": {
    "name": "不落",
    "cost": 2,
    "type": "技能",
    "color": "78c9c2",
    "block": 14,
    "retain_block": true,
    "text": "获得14+防御/4+敏捷/8格挡；剩余格挡保留一回合。",
    "price": 4,
    "school": "壁垒"
  },
  "surge": {
    "name": "燃志",
    "cost": 0,
    "type": "技能",
    "color": "eab483",
    "energy": 2,
    "hp_cost": 5,
    "exhaust": true,
    "text": "失去5生命，获得2战意。消耗。不能支付致死代价。",
    "price": 3,
    "school": "锋刃"
  },
  "study": {
    "name": "研习",
    "cost": 0,
    "type": "筹备",
    "color": "b4a2e0",
    "runes": 2,
    "exhaust": true,
    "text": "获得2灵纹，可在研习市场购牌或精简。消耗；灵纹本次探索保留，上限12。"
  },
  "forge": {
    "name": "战意熔炉",
    "cost": 0,
    "type": "阵式",
    "color": "eab483",
    "construct": "forge",
    "price": 5,
    "school": "锋刃",
    "text": "入场后留在场上。从下回合起每回合额外+1战意。本场有效。"
  },
  "ward": {
    "name": "守护矩阵",
    "cost": 0,
    "type": "阵式",
    "color": "78c9c2",
    "construct": "ward",
    "price": 5,
    "school": "壁垒",
    "text": "入场后留在场上。从下回合起每回合获得5格挡。本场有效。"
  }
}
const STARTER := ["strike","strike","strike","guard","guard","study","study","focus","dash"]
const REWARDS := ["reap","riposte","echo","bastion","surge","rupture","break","quick"]
const MARKET := ["reap","riposte","echo","bastion","surge","rupture","break","quick","forge","ward"]
static func get_card(id: String) -> Dictionary:
	return DATA.get(id,{})
