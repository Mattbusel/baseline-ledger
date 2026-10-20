"""Baseline Ledger In-App Events: the 1.2 premiere (Lock Screen scoring) and the November Serve Challenge.

    python Store/events.py <media dir> [--dry]      create/update both events, upload media, print state
    python Store/events.py submit                   add both events to the app's draft review submission

Media dir: card-<key>.png (1920x1080) and details-<key>.png (1080x1920) for key in (premiere, serve),
made by Store/art/event_media.mjs. Idempotent: events are matched on their reference name.
"""
import json
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813452278"

EVENTS = {
    "premiere": dict(
        ref="Baseline Ledger 1.2: score from the Lock Screen",
        badge="MAJOR_UPDATE", deep="baselineledger://score", purpose="APPROPRIATE_FOR_ALL_USERS",
        schedule={"publishStart": "2026-10-24T14:00:00Z", "eventStart": "2026-10-26T14:00:00Z", "eventEnd": "2026-11-23T14:00:00Z"},
        copy={
            "en-US": ("Score From Your Lock Screen", "Tap Won, Lost or Fault without unlocking",
                      "Live match scoring with the score on your Lock Screen, a weekly practice plan and pressure stats."),
            "en-GB": ("Score From Your Lock Screen", "Tap Won, Lost or Fault without unlocking",
                      "Live match scoring with the score on your Lock Screen, a weekly practice plan and pressure stats."),
            "en-AU": ("Score From Your Lock Screen", "Tap Won, Lost or Fault without unlocking",
                      "Live match scoring with the score on your Lock Screen, a weekly practice plan and pressure stats."),
            "en-CA": ("Score From Your Lock Screen", "Tap Won, Lost or Fault without unlocking",
                      "Live match scoring with the score on your Lock Screen, a weekly practice plan and pressure stats."),
            "es-MX": ("Marca desde la pantalla", "Gané, perdí o falta sin desbloquear",
                      "Marcador en vivo en la pantalla bloqueada, un plan de práctica semanal y estadísticas de presión."),
            "es-ES": ("Puntúa desde la pantalla", "Ganado, perdido o falta sin desbloquear",
                      "Marcador en directo en la pantalla bloqueada, un plan de entreno semanal y estadísticas de presión."),
            "de-DE": ("Punkte vom Sperrbildschirm", "Gewonnen, verloren, Fehler: ohne Entsperren",
                      "Live-Zählung mit dem Spielstand auf dem Sperrbildschirm, Wochen-Trainingsplan und Druckpunkte."),
            "fr-FR": ("Marquez sans déverrouiller", "Gagné, perdu ou faute depuis l'écran verrouillé",
                      "Le score en direct sur l'écran verrouillé, un plan d'entraînement chaque semaine et vos stats sous pression."),
            "pt-BR": ("Marque pela tela bloqueada", "Ganhei, perdi ou falta sem desbloquear",
                      "Placar ao vivo na tela bloqueada, um plano de treino toda semana e estatísticas sob pressão."),
            "it": ("Segna dalla schermata blocco", "Vinto, perso o fallo senza sbloccare",
                   "Punteggio dal vivo sulla schermata di blocco, un piano di allenamento ogni settimana e statistiche sotto pressione."),
            "ja": ("ロック画面からスコア入力", "ロック解除なしで取った・取られた・フォルト",
                   "ロック画面にライブスコア。毎週の練習プランと、プレッシャー場面のスタッツも。"),
            "ko": ("잠금 화면에서 점수 기록", "잠금 해제 없이 득점, 실점, 폴트",
                   "잠금 화면의 실시간 스코어, 매주 새로운 연습 플랜, 압박 상황 통계까지."),
            "zh-Hans": ("在锁屏上直接记分", "无需解锁,点得分、失分或发球失误",
                        "锁屏实时比分,每周训练计划,还有关键分统计。"),
        }),
    "serve": dict(
        ref="November Serve Challenge 2026",
        badge="CHALLENGE", deep="baselineledger://challenge", purpose="APPROPRIATE_FOR_ALL_USERS",
        schedule={"publishStart": "2026-10-26T14:00:00Z", "eventStart": "2026-11-01T12:00:00Z", "eventEnd": "2026-11-30T23:00:00Z"},
        copy={
            "en-US": ("The November Serve Challenge", "300 serves, 60% in, 6 sessions: earn the medal",
                      "Three targets that count themselves from what you log. Finish all three in November for the medal."),
            "en-GB": ("The November Serve Challenge", "300 serves, 60% in, 6 sessions: earn the medal",
                      "Three targets that count themselves from what you log. Finish all three in November for the medal."),
            "en-AU": ("The November Serve Challenge", "300 serves, 60% in, 6 sessions: earn the medal",
                      "Three targets that count themselves from what you log. Finish all three in November for the medal."),
            "en-CA": ("The November Serve Challenge", "300 serves, 60% in, 6 sessions: earn the medal",
                      "Three targets that count themselves from what you log. Finish all three in November for the medal."),
            "es-MX": ("Reto del Saque de Noviembre", "300 saques, 60% dentro, 6 sesiones",
                      "Tres metas que se cuentan solas con lo que registras. Complétalas en noviembre y gana la medalla."),
            "es-ES": ("Reto del Saque de Noviembre", "300 saques, 60% dentro, 6 sesiones",
                      "Tres objetivos que se cuentan solos con lo que registras. Complétalos en noviembre y gana la medalla."),
            "de-DE": ("Aufschlag-Challenge November", "300 Aufschläge, 60% drin, 6 Einheiten",
                      "Drei Ziele, die sich aus deinen Einträgen selbst zählen. Schaffe alle im November für die Medaille."),
            "fr-FR": ("Défi Service de novembre", "300 services, 60% de premières, 6 séances",
                      "Trois objectifs qui se comptent seuls d'après ce que vous notez. Réussissez-les en novembre."),
            "pt-BR": ("Desafio do Saque de Novembro", "300 saques, 60% dentro, 6 treinos",
                      "Três metas que se contam sozinhas pelo que você registra. Complete as três em novembro e ganhe a medalha."),
            "it": ("Sfida del Servizio di Novembre", "300 servizi, 60% dentro, 6 sessioni",
                   "Tre obiettivi che si contano da soli da ciò che registri. Completali a novembre per la medaglia."),
            "ja": ("11月のサーブチャレンジ", "サーブ300本、確率60%、練習6回",
                   "記録するだけで自動でカウントされる3つの目標。11月中に達成してメダルを獲得しよう。"),
            "ko": ("11월 서브 챌린지", "서브 300개, 성공률 60%, 연습 6회",
                   "기록만 하면 자동으로 집계되는 세 가지 목표. 11월 안에 모두 달성하고 메달을 받으세요."),
            "zh-Hans": ("十一月发球挑战", "发球 300 个、一发 60%、练习 6 次",
                        "三个目标会根据你的记录自动统计。十一月内全部完成,赢得奖牌。"),
        }),
}


def check():
    for key, e in EVENTS.items():
        for loc, (n, s, l) in e["copy"].items():
            assert len(n) <= 30 and len(s) <= 50 and len(l) <= 120, (key, loc, len(n), len(s), len(l))
            assert "—" not in n + s + l and "–" not in n + s + l, (key, loc)
    print("copy ok")


def upsert(key, media: Path):
    e = EVENTS[key]
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    existing = [x for x in asc.call("GET", f"/v1/apps/{APP}/appEvents", params={"limit": 50})["data"] if x["attributes"]["referenceName"] == e["ref"]]
    attrs = {"referenceName": e["ref"], "badge": e["badge"], "deepLink": e["deep"], "primaryLocale": "en-US", "priority": "HIGH",
             "purpose": e["purpose"], "territorySchedules": [dict(territories=terr, **e["schedule"])]}
    if existing:
        ev = existing[0]
        asc.call("PATCH", f"/v1/appEvents/{ev['id']}", {"data": {"type": "appEvents", "id": ev["id"], "attributes": {k: v for k, v in attrs.items() if k != "referenceName"}}})
        print(key, "reusing", ev["id"], ev["attributes"]["eventState"])
    else:
        r = asc.call("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": attrs, "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        if not r:
            sys.exit(f"{key}: create failed")
        ev = r["data"]; print(key, "created", ev["id"])
    locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/appEvents/{ev['id']}/localizations", params={"limit": 50})["data"]}
    for loc, (n, s, l) in e["copy"].items():
        a = {"name": n, "shortDescription": s, "longDescription": l}
        if loc in locs:
            asc.call("PATCH", f"/v1/appEventLocalizations/{locs[loc]['id']}", {"data": {"type": "appEventLocalizations", "id": locs[loc]["id"], "attributes": a}})
        else:
            made = asc.call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations", "attributes": dict(locale=loc, **a),
                            "relationships": {"appEvent": {"data": {"type": "appEvents", "id": ev["id"]}}}}})
            if not made:
                print("  localization", loc, "FAILED"); continue
            locs[loc] = made["data"]
        lid = locs[loc]["id"]
        have = {x["attributes"]["appEventAssetType"] for x in asc.call("GET", f"/v1/appEventLocalizations/{lid}/appEventScreenshots")["data"]}
        for kind, f in (("EVENT_CARD", media / f"card-{key}.png"), ("EVENT_DETAILS_PAGE", media / f"details-{key}.png")):
            if kind in have:
                continue
            data = f.read_bytes()
            made = asc.call("POST", "/v1/appEventScreenshots", {"data": {"type": "appEventScreenshots",
                            "attributes": {"fileName": f.name, "fileSize": len(data), "appEventAssetType": kind},
                            "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": lid}}}}})
            if not made:
                print("  media", loc, kind, "FAILED"); continue
            made = made["data"]
            for op in made["attributes"]["uploadOperations"]:
                h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
                requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
            asc.call("PATCH", f"/v1/appEventScreenshots/{made['id']}", {"data": {"type": "appEventScreenshots", "id": made["id"], "attributes": {"uploaded": True}}})
        print("  ", loc, "ok")
    time.sleep(5)
    ev = asc.call("GET", f"/v1/appEvents/{ev['id']}")["data"]
    print(key, "state:", ev["attributes"]["eventState"])
    return ev["id"]


if __name__ == "__main__":
    check()
    if "--dry" in sys.argv:
        sys.exit()
    ids = {k: upsert(k, Path(sys.argv[1])) for k in EVENTS}
    print(json.dumps(ids))
