extends RefCounted
## Original cards. Values scale from equipped RPG stats; IDs are stable save keys.
const DATA := {
	"strike":{"name":"折光斩","cost":1,"type":"攻击","color":"eab483","attack":0.65,"flat":2,"text":"造成攻击力 65% + 2 的伤害。"},
	"guard":{"name":"守势","cost":1,"type":"技能","color":"78c9c2","block":7,"text":"获得 7 + 防御/3 + 敏捷/6 点格挡。"},
	"rupture":{"name":"血线","cost":1,"type":"攻击","color":"e194a6","attack":0.4,"flat":1,"bleed":3,"text":"造成攻击力 40% + 1 伤害。施加流血 3，持续 2 回合。"},
	"break":{"name":"破阵","cost":2,"type":"攻击","color":"eab483","attack":0.9,"flat":4,"stagger":7,"vulnerable":2,"text":"造成攻击力 90% + 4 伤害。削韧 7，施加 2 回合易伤。"},
	"focus":{"name":"灵光","cost":0,"type":"技能","color":"b4a2e0","draw":2,"exhaust":true,"text":"抽 2 张牌。消耗：本场战斗不再抽到。"},
	"dash":{"name":"掠影","cost":1,"type":"技能","color":"78c9c2","block":3,"momentum":0.4,"text":"获得 3 + 防御/3 + 敏捷/6 格挡。下一次攻击增伤 40% + 移动力 × 5%。"},
	"heavy":{"name":"断碑","cost":2,"type":"攻击","color":"eab483","attack":1.3,"flat":5,"stagger":5,"text":"长剑装备牌。造成攻击力 130% + 5 伤害，削韧 5。"},
	"quick":{"name":"鸦羽","cost":1,"type":"攻击","color":"e194a6","attack":0.5,"flat":2,"draw":1,"text":"短刃装备牌。造成攻击力 50% + 2 伤害，抽 1 张牌。"},
	"shadowstep":{"name":"影步","cost":0,"type":"技能","color":"b4a2e0","block":4,"momentum":0.5,"exhaust":true,"text":"词条专属。获得格挡，下一击增伤 50% + 移动力 × 5%。消耗。"},
	"reap":{"name":"收割","cost":1,"type":"攻击","color":"e194a6","attack":0.7,"flat":2,"bleed_bonus":8,"text":"造成攻击力 70% + 2 伤害。目标流血时额外造成 8 伤害。"},
	"riposte":{"name":"交锋","cost":1,"type":"攻击","color":"78c9c2","attack":0.4,"flat":1,"block":5,"text":"造成攻击力 40% + 1 伤害，并获得格挡。"},
	"echo":{"name":"心刃","cost":1,"type":"攻击","color":"b4a2e0","attack":0.25,"will":0.15,"flat":2,"text":"造成攻击力 25% + 意志 15% + 2 伤害，无视护甲。"},
	"bastion":{"name":"不落","cost":2,"type":"技能","color":"78c9c2","block":17,"retain_block":true,"text":"获得大量格挡。剩余格挡保留至下一回合。"},
	"surge":{"name":"燃志","cost":0,"type":"技能","color":"eab483","energy":2,"hp_cost":5,"exhaust":true,"text":"失去 5 生命，获得 2 能量。消耗。生命不足时无法打出。"}
}
const STARTER := ["strike","strike","strike","guard","guard","guard","rupture","break","focus","dash"]
const REWARDS := ["reap","riposte","echo","bastion","surge","rupture","break","quick"]
static func get_card(id: String) -> Dictionary:
	return DATA.get(id,{})
