"""Live smoke test. Only the fixed staging project and synthetic student are used."""
import json
from urllib.request import Request, urlopen
from urllib.error import HTTPError

BASE = "https://yyqeymyopawhaniyemqo.supabase.co/rest/v1/"
KEY = "sb_publishable_7OCyIvEzWY8aQXqi3rAQww_ku-Q81tx"
TOKEN = "f17a0d6e9b249631a86d5a70c12909a209d19c808c51765cdfa9c6d8bea67942"

def request(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = Request(BASE + path, data=data, headers={"apikey": KEY, "Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=25) as response:
            return response.status, json.load(response)
    except HTTPError as e:
        return e.code, json.loads(e.read())

def rpc(name, body):
    status, result = request("rpc/" + name, body)
    assert status == 200, (name, status, result)
    return result

def main():
    started = rpc("v5_start_exam", {"p_token": TOKEN, "p_student_code": " staging-student-001 "})
    assert started["status"] == "started", started
    args = {"p_attempt_id": started["attempt_id"], "p_student_code": started["student_code"]}
    state = rpc("v5_get_attempt_state", args)
    assert state["deadline_at"] and state["server_now"], state
    rows = rpc("v5_get_exam_questions", args)
    assert len(rows) == 12 and all("is_correct" not in row for row in rows)
    denied, _ = request("rpc/v5_get_attempt_state", dict(args, p_student_code="WRONG-STUDENT"))
    assert denied >= 400, "Wrong student was accepted"
    for row in rows:
        if row["option_key"] == "A":
            saved = rpc("v5_save_answer", dict(args, p_exam_question_id=row["id"], p_selected_option_id=row["option_id"]))
            assert saved["saved"], saved
    resumed = rpc("v5_start_exam", {"p_token": TOKEN, "p_student_code": started["student_code"]})
    assert resumed["attempt_id"] == started["attempt_id"]
    result = rpc("v5_submit_attempt", args)
    assert result["status"] == "submitted" and float(result["percentage"]) == 100, result
    retry = rpc("v5_submit_attempt", args)
    assert retry == result, (retry, result)
    denied, _ = request("rpc/v5_get_staff_exam_publish_list", {})
    assert denied >= 400, "Anonymous caller could access staff RPC"
    for table in ["v5_students", "v5_question_options"]:
        status, data = request(table + "?select=*")
        assert status >= 400 or data == [], (table, status, data)
    print(json.dumps({"passed": True, "attempt_id": started["attempt_id"],
                      "percentage": result["percentage"], "questions": 3,
                      "checks": ["canonical code", "deadline", "question secrecy", "wrong student denied",
                                 "save", "resume", "score", "idempotent submit", "staff denied", "table RLS"]}))

if __name__ == "__main__":
    main()
