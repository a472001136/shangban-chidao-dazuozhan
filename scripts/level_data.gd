extends RefCounted
class_name LevelData

static func get_level(index: int) -> Dictionary:
	var level: Dictionary
	match clampi(index,0,5):
		0: level = _tutorial()
		1: level = _monday()
		2: level = _tuesday()
		3: level = _wednesday()
		4: level = _thursday()
		_: level = _friday()
	if not level.has("hr"):
		var width: float = float(level.width)
		level["hr"] = [{"pos":Vector2(width*0.36,600),"left":width*0.33,"right":width*0.4},{"pos":Vector2(width*0.72,600),"left":width*0.7,"right":width*0.76}]
		level["busy_zones"] = []
		for furniture in level.furniture:
			if furniture.kind=="desk":
				level.busy_zones.append({"x":float(furniture.x),"y":600.0})
	return level

static func _tutorial() -> Dictionary:
	var introduction: Dictionary = _office_intro()
	introduction["name"] = "入职第一滑"
	introduction["day"] = "教学"
	introduction["notice"] = "先按 E 坐椅子，A/D 蹬地，S 刹车。人事靠近时可在绿线处按住 Q 装忙。"
	introduction["limit"] = 80.0
	introduction["efficient"] = 0.0
	introduction["challenge"] = "绕开查考勤的人事，按 E 打卡"
	introduction["challenge_kind"] = "tutorial"
	introduction["coupons"] = []
	return introduction


static func _office_intro() -> Dictionary:
	return {
		"name":"日报就一行，人事看两遍", "day":"周一", "chaos_playground":true,
		"notice":"人事正在抓迟到。请在被登记前抵达工位，奖金五十元，损失另算。",
		"limit":65.0,"efficient":25.0,"challenge":"推动会议桌，挡住一次追赶的人事","challenge_kind":"table_block",
		"width":4800.0,"theme":1,"spawn":Vector2(160,600),"goal":Vector2(4370,600),
		"safe_points":[Vector2(160,600),Vector2(1600,600),Vector2(3000,600),Vector2(4200,600)],
		"ground":[{"x1":0.0,"x2":4800.0,"y":600.0}],
		"ramps":[{"x1":350.0,"x2":620.0,"y1":600.0,"y2":550.0},{"x1":620.0,"x2":850.0,"y1":550.0,"y2":600.0}],
		"platforms":[{"x":1810.0,"y":535.0,"w":100.0},{"x":1930.0,"y":470.0,"w":100.0},{"x":2050.0,"y":405.0,"w":880.0},{"x":3560.0,"y":440.0,"w":260.0}],
		"furniture":[{"kind":"reception","x":40.0,"y":600.0,"size":Vector2(160,140)},{"kind":"desk","x":970.0,"y":600.0,"size":Vector2(220,150)},{"kind":"desk","x":3050.0,"y":600.0,"size":Vector2(220,150)}],
		"busy_zones":[{"x":970.0,"y":600.0},{"x":3050.0,"y":600.0}],
		"hr":[{"pos":Vector2(1150,600),"left":1060.0,"right":1300.0},{"pos":Vector2(2700,600),"left":2500.0,"right":2830.0},{"pos":Vector2(4060,600),"left":3980.0,"right":4200.0}],
		"npcs":[{"kind":"receptionist","x":70.0,"y":545.0,"facing":1},{"kind":"coworker","x":3230.0,"y":545.0,"facing":-1}],
		"props":[
			{"id":"mon_box","kind":"box","x":600.0,"y":554.0,"size":Vector2(76,62),"cost":30,"threshold":370.0,"blocking":true},
			{"id":"mon_cooler","kind":"cooler","x":1480.0,"y":600.0,"size":Vector2(82,178),"cost":800,"threshold":360.0,"blocking":true},
			{"id":"mon_files","kind":"files","x":1690.0,"y":600.0,"size":Vector2(76,58),"cost":30,"threshold":360.0,"blocking":true},
			{"id":"mon_printer","kind":"printer","x":2330.0,"y":600.0,"size":Vector2(112,128),"cost":2000,"threshold":360.0,"blocking":true},
			{"id":"mon_meeting","kind":"meeting","x":3410.0,"y":600.0,"size":Vector2(380,112),"cost":0,"threshold":360.0,"blocking":true},
			{"id":"mon_plant","kind":"plant","x":3880.0,"y":600.0,"size":Vector2(86,120),"cost":120,"threshold":380.0,"blocking":true}
		],
		"tools":[{"id":1,"kind":"chair","pos":Vector2(205,600),"fuel":1.0},{"id":2,"kind":"extinguisher","pos":Vector2(2170,405),"fuel":1.0},{"id":3,"kind":"chair","pos":Vector2(3020,600),"fuel":1.0},{"id":4,"kind":"bucket","pos":Vector2(1560,600),"fuel":1.0}],
		"coupons":[{"id":0,"pos":Vector2(760,450)},{"id":1,"pos":Vector2(2530,340)},{"id":2,"pos":Vector2(3680,400)}],
		"wet_zones":[],"mechanisms":[],"supervisor":{},
		"route_signs":[{"x":270.0,"label":"E 坐椅子 · S 刹车"},{"x":1090.0,"y":390.0,"label":"人事查考勤 ↑"},{"x":1590.0,"y":395.0,"label":"空格离椅 · 跳过滚桶"},{"x":1860.0,"y":345.0,"label":"空格跳上员工通道"},{"x":3230.0,"y":385.0,"label":"A/D 推会议桌"},{"x":4280.0,"label":"E 打卡 · 结束追赶"}]
	}


static func _monday() -> Dictionary:
	return {
		"name":"办公室临时改道", "day":"周一", "chaos_playground":true, "tactical":true,
		"notice":"高速起跳保留惯性，落地前按 Shift 接冲刺。\n四秒内接动作涨倍率；擦身避开查岗加分。",
		"limit":55.0, "efficient":22.0, "challenge":"组合两种办法脱身：诱饵、装忙、遮挡、推桌或连锁事故", "challenge_kind":"tactical_combo",
		"width":3800.0, "theme":1, "spawn":Vector2(160,600), "goal":Vector2(3480,600),
		"ground":[{"x1":0.0,"x2":3800.0,"y":600.0}], "ramps":[],
		"platforms":[
			{"x":450.0,"y":500.0,"w":100.0}, {"x":730.0,"y":400.0,"w":120.0},
			{"x":950.0,"y":330.0,"w":300.0}, {"x":1260.0,"y":500.0,"w":90.0},
			{"x":1480.0,"y":410.0,"w":100.0}, {"x":1700.0,"y":330.0,"w":280.0},
			{"x":2750.0,"y":500.0,"w":70.0},
			{"x":2950.0,"y":400.0,"w":80.0}, {"x":3220.0,"y":300.0,"w":180.0}
		],
		"furniture":[{"kind":"desk","x":600.0,"y":600.0,"size":Vector2(180,150)}, {"kind":"desk","x":2020.0,"y":600.0,"size":Vector2(180,150)}],
		"busy_zones":[{"x":600.0,"y":600.0},{"x":2020.0,"y":600.0}],
		"hr":[{"pos":Vector2(960,600),"left":880.0,"right":1070.0}, {"pos":Vector2(2160,600),"left":2050.0,"right":2240.0}, {"pos":Vector2(3330,600),"left":3240.0,"right":3390.0}],
		"props":[
			{"id":"mon_box","kind":"box","x":350.0,"y":600.0,"size":Vector2(64,58),"cost":30,"threshold":370.0},
			{"id":"mon_printer","kind":"printer","x":1140.0,"y":600.0,"size":Vector2(112,112),"cost":2000,"threshold":420.0},
			{"id":"mon_cooler","kind":"cooler","x":1700.0,"y":600.0,"size":Vector2(82,178),"cost":800,"threshold":360.0},
			{"id":"mon_files","kind":"files","x":1950.0,"y":600.0,"size":Vector2(76,58),"cost":30,"threshold":390.0,"chain_threshold":140.0},
			{"id":"mon_meeting","kind":"meeting","x":2430.0,"y":600.0,"size":Vector2(380,112),"cost":0,"threshold":360.0}
		],
		"tools":[{"id":1,"kind":"chair","pos":Vector2(205,600),"fuel":1.0}, {"id":2,"kind":"extinguisher","pos":Vector2(1840,330),"fuel":1.0}, {"id":3,"kind":"chair","pos":Vector2(1460,600),"fuel":1.0}, {"id":4,"kind":"extinguisher","pos":Vector2(2020,600),"fuel":0.55}],
		"coupons":[{"id":0,"pos":Vector2(1030,280)}, {"id":1,"pos":Vector2(1840,280)}, {"id":2,"pos":Vector2(3150,250)}],
		"controls":[{"id":"copy","pos":Vector2(280,600),"target":Vector2(1140,600),"label":"F 远程复印 · 引开人事"}, {"id":"gate","pos":Vector2(2680,600),"target":Vector2(3050,600),"label":"F 门禁放行 4 秒"}],
		"gate":{"x":3050.0,"y":600.0,"height":240.0,"trigger":2650.0,"warning":2.8},
		"hr_detours":[{"x1":3032.0,"x2":3068.0,"left":[Vector2(2780,500),Vector2(2990,400),Vector2(3290,300),Vector2(3470,600)],"right":[Vector2(3290,300),Vector2(2990,400),Vector2(2780,500)]}],
		"wet_zones":[],"mechanisms":[],"supervisor":{}, "npcs":[],
		"route_signs":[{"x":240.0,"y":395.0,"label":"E 骑椅 · F 踢出诱饵"}, {"x":500.0,"y":280.0,"label":"↑ 上层绕行 / 地面引开"}, {"x":1350.0,"y":260.0,"label":"↑ 绕路 / 撞水机开路"}, {"x":1970.0,"y":230.0,"label":"E 拿灭火器 · F 喷粉"}, {"x":2310.0,"y":335.0,"label":"A/D 推桌 · 改变通道"}, {"x":2770.0,"y":230.0,"label":"门禁临检 · 开门或翻越"}, {"x":3480.0,"label":"落地 E 打卡"}]
	}


static func _tuesday() -> Dictionary:
	return {
		"name": "公司今天搬家",
		"day": "周二",
		"notice": "搬运期间，请勿影响正常办公。",
		"limit": 110.0,
		"efficient": 55.0,
		"challenge": "骑椅穿过指定纸箱墙",
		"challenge_kind": "chair_wall",
		"width": 8400.0,
		"theme": 2,
		"spawn": Vector2(96.0, 600.0),
		"goal": Vector2(7900.0, 600.0),
		"safe_points": [Vector2(96.0, 600.0), Vector2(1620.0, 600.0), Vector2(3200.0, 600.0), Vector2(4820.0, 600.0), Vector2(6380.0, 600.0), Vector2(7720.0, 600.0)],
		"ground": [{"x1": 0.0, "x2": 8400.0, "y": 600.0}],
		"ramps": [{"x1": 1940.0, "x2": 2240.0, "y1": 600.0, "y2": 538.0}, {"x1": 2240.0, "x2": 2600.0, "y1": 538.0, "y2": 600.0}, {"x1": 4180.0, "x2": 4580.0, "y1": 600.0, "y2": 548.0}, {"x1": 4580.0, "x2": 4980.0, "y1": 548.0, "y2": 600.0}],
		"platforms": [{"x": 2240.0, "y": 538.0, "w": 360.0}, {"x": 3360.0, "y": 500.0, "w": 340.0}, {"x": 4580.0, "y": 548.0, "w": 400.0}, {"x": 6030.0, "y": 480.0, "w": 330.0}],
		"furniture": [{"kind": "shelf", "x": 760.0, "y": 600.0, "size": Vector2(190.0, 210.0)}, {"kind": "desk", "x": 1590.0, "y": 600.0, "size": Vector2(220.0, 150.0)}, {"kind": "cabinet", "x": 2860.0, "y": 600.0, "size": Vector2(185.0, 225.0)}, {"kind": "desk", "x": 3920.0, "y": 600.0, "size": Vector2(210.0, 150.0)}, {"kind": "shelf", "x": 5370.0, "y": 600.0, "size": Vector2(190.0, 220.0)}, {"kind": "desk", "x": 6960.0, "y": 600.0, "size": Vector2(220.0, 150.0)}],
		"npcs": [{"kind": "coworker", "x": 2810.0, "y": 600.0, "facing": 1}, {"kind": "coworker", "x": 5510.0, "y": 600.0, "facing": -1}],
		"props": [{"id": "tue_box_1", "kind": "box", "x": 1900.0, "y": 600.0, "size": Vector2(90.0, 78.0), "cost": 30, "threshold": 440.0, "blocking": true}, {"id": "tue_box_wall", "kind": "box", "x": 3090.0, "y": 600.0, "size": Vector2(158.0, 104.0), "cost": 30, "threshold": 480.0, "blocking": true, "challenge_kind": "chair_wall"}, {"id": "tue_files_1", "kind": "files", "x": 3650.0, "y": 600.0, "size": Vector2(78.0, 62.0), "cost": 30, "threshold": 390.0, "blocking": false}, {"id": "tue_bin_1", "kind": "bin", "x": 5130.0, "y": 600.0, "size": Vector2(62.0, 94.0), "cost": 80, "threshold": 450.0, "blocking": true}, {"id": "tue_plant_1", "kind": "plant", "x": 6720.0, "y": 600.0, "size": Vector2(86.0, 120.0), "cost": 120, "threshold": 430.0, "blocking": false}],
		"tools": [{"id": 1, "kind": "chair", "pos": Vector2(1180.0, 600.0), "fuel": 1.0}],
		"coupons": [{"id": 0, "pos": Vector2(860.0, 500.0)}, {"id": 1, "pos": Vector2(4440.0, 500.0)}, {"id": 2, "pos": Vector2(6210.0, 420.0)}],
		"wet_zones": [],
		"mechanisms": [{"kind": "belt", "x1": 4050.0, "x2": 4900.0, "y": 600.0, "direction": 1.0, "period": 0.0, "phase": 0.0}],
		"supervisor": {},
		"route_signs": [{"x": 2120.0, "label": "搬运通道"}, {"x": 3020.0, "label": "纸箱墙捷径"}, {"x": 4300.0, "label": "运输带"}]
	}

static func _wednesday() -> Dictionary:
	return {
		"name": "空调坏了怎么办",
		"day": "周三",
		"notice": "办公室临时采用自然通风。",
		"limit": 120.0,
		"efficient": 60.0,
		"challenge": "沿实体台阶到达上层阳台",
		"challenge_kind": "balcony",
		"width": 8600.0,
		"theme": 3,
		"spawn": Vector2(96.0, 600.0),
		"goal": Vector2(8100.0, 600.0),
		"safe_points": [Vector2(96.0, 600.0), Vector2(1640.0, 600.0), Vector2(3250.0, 600.0), Vector2(4800.0, 600.0), Vector2(6400.0, 600.0), Vector2(7920.0, 600.0)],
		"ground": [{"x1": 0.0, "x2": 8600.0, "y": 600.0}],
		"ramps": [{"x1": 2180.0, "x2": 2520.0, "y1": 600.0, "y2": 530.0}, {"x1": 2520.0, "x2": 2840.0, "y1": 530.0, "y2": 600.0}, {"x1": 5980.0, "x2": 6320.0, "y1": 600.0, "y2": 540.0}, {"x1": 6320.0, "x2": 6680.0, "y1": 540.0, "y2": 600.0}],
		"platforms": [{"x": 2520.0, "y": 530.0, "w": 320.0}, {"x": 3320.0, "y": 500.0, "w": 250.0}, {"x": 3570.0, "y": 465.0, "w": 250.0}, {"x": 3820.0, "y": 430.0, "w": 250.0}, {"x": 4070.0, "y": 400.0, "w": 250.0}, {"x": 4320.0, "y": 374.0, "w": 250.0}, {"x": 4570.0, "y": 354.0, "w": 300.0}, {"x": 4870.0, "y": 354.0, "w": 500.0}, {"x": 5370.0, "y": 354.0, "w": 520.0}, {"x": 5890.0, "y": 354.0, "w": 370.0}, {"x": 6200.0, "y": 540.0, "w": 360.0}],
		"furniture": [{"kind": "desk", "x": 740.0, "y": 600.0, "size": Vector2(220.0, 150.0)}, {"kind": "shelf", "x": 1820.0, "y": 600.0, "size": Vector2(180.0, 220.0)}, {"kind": "fan", "x": 3060.0, "y": 600.0, "size": Vector2(150.0, 125.0)}, {"kind": "shelf", "x": 4440.0, "y": 600.0, "size": Vector2(180.0, 215.0)}, {"kind": "printer", "x": 5750.0, "y": 600.0, "size": Vector2(116.0, 128.0)}, {"kind": "desk", "x": 7280.0, "y": 600.0, "size": Vector2(220.0, 150.0)}],
		"npcs": [{"kind": "coworker", "x": 3760.0, "y": 600.0, "facing": 1}, {"kind": "coworker", "x": 6920.0, "y": 600.0, "facing": -1}],
		"props": [{"id": "wed_box_1", "kind": "box", "x": 1650.0, "y": 600.0, "size": Vector2(82.0, 78.0), "cost": 30, "threshold": 440.0, "blocking": true}, {"id": "wed_printer_1", "kind": "printer", "x": 5660.0, "y": 600.0, "size": Vector2(112.0, 128.0), "cost": 2000, "threshold": 510.0, "blocking": false}, {"id": "wed_files_1", "kind": "files", "x": 6920.0, "y": 600.0, "size": Vector2(76.0, 58.0), "cost": 30, "threshold": 390.0, "blocking": false}],
		"tools": [{"id": 1, "kind": "extinguisher", "pos": Vector2(1880.0, 600.0), "fuel": 1.0}],
		"coupons": [{"id": 0, "pos": Vector2(1150.0, 500.0)}, {"id": 1, "pos": Vector2(3080.0, 422.0)}, {"id": 2, "pos": Vector2(5820.0, 310.0)}],
		"wet_zones": [],
		"mechanisms": [{"kind": "fan", "x1": 2960.0, "x2": 3260.0, "y": 600.0, "strength": 1.0, "period": 3.2, "active_time": 2.2, "phase": 0.0}],
		"supervisor": {},
		"balcony": {"x1": 5280.0, "x2": 6260.0, "y": 354.0},
		"route_signs": [{"x": 1880.0, "label": "备用灭火器"}, {"x": 3060.0, "label": "风扇通道"}, {"x": 5510.0, "label": "阳台捷径"}]
	}

static func _thursday() -> Dictionary:
	return {
		"name": "领导正在视察",
		"day": "周四",
		"notice": "请保持办公环境整洁有序。",
		"limit": 135.0,
		"efficient": 70.0,
		"challenge": "全程不触发训话",
		"challenge_kind": "no_warning",
		"width": 8500.0,
		"theme": 4,
		"spawn": Vector2(96.0, 600.0),
		"goal": Vector2(8000.0, 600.0),
		"safe_points": [Vector2(96.0, 600.0), Vector2(1680.0, 600.0), Vector2(3360.0, 600.0), Vector2(5000.0, 600.0), Vector2(6500.0, 600.0), Vector2(7820.0, 600.0)],
		"ground": [{"x1": 0.0, "x2": 8500.0, "y": 600.0}],
		"ramps": [{"x1": 2900.0, "x2": 3240.0, "y1": 600.0, "y2": 545.0}, {"x1": 3240.0, "x2": 3590.0, "y1": 545.0, "y2": 600.0}, {"x1": 5400.0, "x2": 5760.0, "y1": 600.0, "y2": 530.0}, {"x1": 5760.0, "x2": 6100.0, "y1": 530.0, "y2": 600.0}],
		"platforms": [{"x": 3240.0, "y": 545.0, "w": 350.0}, {"x": 4240.0, "y": 490.0, "w": 380.0}, {"x": 5740.0, "y": 530.0, "w": 360.0}, {"x": 6880.0, "y": 480.0, "w": 420.0}],
		"furniture": [{"kind": "bucket", "x": 720.0, "y": 600.0, "size": Vector2(112.0, 112.0)}, {"kind": "desk", "x": 1880.0, "y": 600.0, "size": Vector2(210.0, 150.0)}, {"kind": "shelf", "x": 3840.0, "y": 600.0, "size": Vector2(180.0, 220.0)}, {"kind": "desk", "x": 4940.0, "y": 600.0, "size": Vector2(210.0, 150.0)}, {"kind": "cabinet", "x": 6340.0, "y": 600.0, "size": Vector2(182.0, 225.0)}, {"kind": "desk", "x": 7330.0, "y": 600.0, "size": Vector2(220.0, 150.0)}],
		"props": [{"id": "thu_box_1", "kind": "box", "x": 1540.0, "y": 600.0, "size": Vector2(86.0, 78.0), "cost": 30, "threshold": 440.0, "blocking": true}, {"id": "thu_plant_1", "kind": "plant", "x": 2700.0, "y": 600.0, "size": Vector2(84.0, 120.0), "cost": 120, "threshold": 430.0, "blocking": false}, {"id": "thu_bin_1", "kind": "bin", "x": 4610.0, "y": 600.0, "size": Vector2(60.0, 92.0), "cost": 80, "threshold": 450.0, "blocking": true}, {"id": "thu_monitor_1", "kind": "monitor", "x": 6680.0, "y": 600.0, "size": Vector2(102.0, 126.0), "cost": 1200, "threshold": 510.0, "blocking": false}],
		"tools": [{"id": 2, "kind": "bucket", "pos": Vector2(1160.0, 600.0), "fuel": 1.0}],
		"coupons": [{"id": 0, "pos": Vector2(950.0, 492.0)}, {"id": 1, "pos": Vector2(4420.0, 440.0)}, {"id": 2, "pos": Vector2(7030.0, 416.0)}],
		"wet_zones": [{"x1": 620.0, "x2": 1320.0, "y": 600.0}, {"x1": 3620.0, "x2": 4050.0, "y": 600.0}],
		"mechanisms": [{"kind": "fan", "x1": 6120.0, "x2": 6400.0, "y": 600.0, "strength": 0.7, "period": 4.0, "active_time": 2.4, "phase": 1.0}],
		"supervisor": {"x": 5900.0, "y": 600.0, "start": 5700.0, "end": 6480.0, "speed": 72.0, "vision": 350.0},
		"route_signs": [{"x": 690.0, "label": "注意地滑"}, {"x": 1180.0, "label": "拖把桶"}, {"x": 5900.0, "label": "视察通道"}]
	}

static func _friday() -> Dictionary:
	return {
		"name": "五十块不能丢",
		"day": "周五",
		"notice": "今日为全勤奖结算日，请全体按时到岗。",
		"limit": 150.0,
		"efficient": 85.0,
		"challenge": "本局触发至少 8 个不同事故物件",
		"challenge_kind": "chaos",
		"width": 9600.0,
		"theme": 5,
		"spawn": Vector2(96.0, 600.0),
		"goal": Vector2(9100.0, 600.0),
		"safe_points": [Vector2(96.0, 600.0), Vector2(1760.0, 600.0), Vector2(3450.0, 600.0), Vector2(5100.0, 600.0), Vector2(6750.0, 600.0), Vector2(8260.0, 600.0), Vector2(8920.0, 600.0)],
		"ground": [{"x1": 0.0, "x2": 9600.0, "y": 600.0}],
		"ramps": [{"x1": 1980.0, "x2": 2360.0, "y1": 600.0, "y2": 540.0}, {"x1": 2360.0, "x2": 2740.0, "y1": 540.0, "y2": 600.0}, {"x1": 4650.0, "x2": 5040.0, "y1": 600.0, "y2": 538.0}, {"x1": 5040.0, "x2": 5430.0, "y1": 538.0, "y2": 600.0}, {"x1": 6950.0, "x2": 7260.0, "y1": 600.0, "y2": 520.0}, {"x1": 7260.0, "x2": 7600.0, "y1": 520.0, "y2": 600.0}],
		"platforms": [{"x": 2360.0, "y": 540.0, "w": 380.0}, {"x": 2970.0, "y": 520.0, "w": 120.0}, {"x": 3160.0, "y": 400.0, "w": 200.0, "thickness": 16.0}, {"x": 3420.0, "y": 490.0, "w": 210.0}, {"x": 5040.0, "y": 538.0, "w": 390.0}, {"x": 6120.0, "y": 480.0, "w": 420.0}, {"x": 7260.0, "y": 520.0, "w": 340.0}, {"x": 7740.0, "y": 480.0, "w": 260.0}, {"x": 8130.0, "y": 414.0, "w": 380.0}],
		"furniture": [{"kind": "reception", "x": 540.0, "y": 600.0, "size": Vector2(205.0, 176.0)}, {"kind": "shelf", "x": 1480.0, "y": 600.0, "size": Vector2(180.0, 210.0)}, {"kind": "desk", "x": 2940.0, "y": 600.0, "size": Vector2(220.0, 150.0)}, {"kind": "fan", "x": 4200.0, "y": 600.0, "size": Vector2(148.0, 125.0)}, {"kind": "shelf", "x": 5670.0, "y": 600.0, "size": Vector2(180.0, 214.0)}, {"kind": "desk", "x": 7810.0, "y": 600.0, "size": Vector2(215.0, 150.0)}, {"kind": "desk", "x": 8840.0, "y": 600.0, "size": Vector2(230.0, 160.0)}],
		"npcs": [{"kind": "coworker", "x": 2890.0, "y": 600.0, "facing": -1}, {"kind": "janitor", "x": 4600.0, "y": 600.0, "facing": 1}],
		"props": [{"id": "fri_box_1", "kind": "box", "x": 1640.0, "y": 600.0, "size": Vector2(86.0, 78.0), "cost": 30, "threshold": 430.0, "blocking": true}, {"id": "fri_files_1", "kind": "files", "x": 2480.0, "y": 540.0, "size": Vector2(78.0, 60.0), "cost": 30, "threshold": 390.0, "blocking": false}, {"id": "fri_cooler_1", "kind": "cooler", "x": 3180.0, "y": 600.0, "size": Vector2(82.0, 178.0), "cost": 800, "threshold": 500.0, "blocking": false}, {"id": "fri_plant_1", "kind": "plant", "x": 3860.0, "y": 600.0, "size": Vector2(84.0, 120.0), "cost": 120, "threshold": 430.0, "blocking": false}, {"id": "fri_bin_1", "kind": "bin", "x": 4560.0, "y": 600.0, "size": Vector2(62.0, 94.0), "cost": 80, "threshold": 450.0, "blocking": true}, {"id": "fri_printer_1", "kind": "printer", "x": 5480.0, "y": 600.0, "size": Vector2(112.0, 128.0), "cost": 2000, "threshold": 500.0, "blocking": false}, {"id": "fri_glass_1", "kind": "glass", "x": 6240.0, "y": 480.0, "size": Vector2(122.0, 156.0), "cost": 600, "threshold": 500.0, "blocking": true}, {"id": "fri_monitor_1", "kind": "monitor", "x": 6670.0, "y": 600.0, "size": Vector2(98.0, 124.0), "cost": 1200, "threshold": 510.0, "blocking": false}, {"id": "fri_box_2", "kind": "box", "x": 7480.0, "y": 600.0, "size": Vector2(88.0, 78.0), "cost": 30, "threshold": 430.0, "blocking": true}, {"id": "fri_files_2", "kind": "files", "x": 8320.0, "y": 600.0, "size": Vector2(78.0, 60.0), "cost": 30, "threshold": 390.0, "blocking": false}, {"id": "fri_plant_2", "kind": "plant", "x": 8610.0, "y": 600.0, "size": Vector2(84.0, 120.0), "cost": 120, "threshold": 430.0, "blocking": false}],
		"tools": [{"id": 1, "kind": "chair", "pos": Vector2(1260.0, 600.0), "fuel": 1.0}, {"id": 2, "kind": "bucket", "pos": Vector2(4240.0, 600.0), "fuel": 1.0}, {"id": 3, "kind": "extinguisher", "pos": Vector2(7040.0, 600.0), "fuel": 1.0}],
		"coupons": [{"id": 0, "pos": Vector2(820.0, 500.0)}, {"id": 1, "pos": Vector2(5230.0, 480.0)}, {"id": 2, "pos": Vector2(8290.0, 380.0)}],
		"wet_zones": [{"x1": 4120.0, "x2": 4850.0, "y": 600.0}],
		"mechanisms": [{"kind": "belt", "x1": 4450.0, "x2": 5000.0, "y": 600.0, "direction": 1.0, "period": 0.0, "phase": 0.0}, {"kind": "fan", "x1": 4050.0, "x2": 4350.0, "y": 600.0, "strength": 0.85, "period": 3.0, "active_time": 2.0, "phase": 0.0}],
		"supervisor": {"x": 7920.0, "y": 600.0, "start": 7600.0, "end": 8390.0, "speed": 78.0, "vision": 350.0},
		"hr_detours": [{"x1": 3139.0, "x2": 3221.0, "left": [Vector2(3040,520), Vector2(3190,400), Vector2(3320,400), Vector2(3460,490)], "right": [Vector2(3460,490), Vector2(3320,400), Vector2(3190,400), Vector2(3040,520), Vector2(2900,600)]}],
		"route_signs": [{"x": 1240.0, "label": "办公椅"}, {"x": 2940.0, "y": 350.0, "label": "按住空格 · 分两次跳"}, {"x": 3160.0, "y": 270.0, "label": "检修通道 →"}, {"x": 3100.0, "y": 450.0, "label": "← 踏台 / Shift 撞开"}, {"x": 4200.0, "label": "湿滑区"}, {"x": 7060.0, "label": "灭火器"}]
	}
